import Foundation
import UIKit
import Vision
import CoreImage.CIFilterBuiltins

/// Lee tickets con el OCR del sistema (Vision, 100% on-device) y extrae
/// el total, el comercio y la fecha con heurísticas pensadas para
/// tickets argentinos (números con coma decimal, fechas dd/mm/aaaa).
enum TicketScannerService {

    struct DatosTicket {
        var monto: Double?
        var nombre: String?
        var fecha: Date?

        var estaVacio: Bool { monto == nil && nombre == nil && fecha == nil }
    }

    // MARK: - OCR

    /// Reconoce el texto de la imagen y lo interpreta como ticket.
    /// Antes de leer, busca el ticket dentro de la foto y lo endereza:
    /// una foto sacada a mano (torcida, con fondo) lee mucho mejor así.
    static func analizar(_ imagen: UIImage) async -> DatosTicket {
        await Task.detached(priority: .userInitiated) { () -> DatosTicket in
            guard let base = normalizada(imagen) else { return DatosTicket() }

            // 1) Con el ticket recortado y enderezado.
            if let recorte = recorteDeDocumento(en: base) {
                let datos = parsear(lineas: reconocerTexto(en: recorte))
                if datos.monto != nil { return datos }

                // 2) El recorte no alcanzó: probar con la foto completa
                //    y quedarse con el mejor resultado.
                let datosCompleta = parsear(lineas: reconocerTexto(en: base))
                if datosCompleta.monto != nil { return datosCompleta }
                return datos.estaVacio ? datosCompleta : datos
            }

            return parsear(lineas: reconocerTexto(en: base))
        }.value
    }

    private static func reconocerTexto(en cgImage: CGImage) -> [String] {
        let pedido = VNRecognizeTextRequest()
        pedido.recognitionLevel = .accurate
        pedido.recognitionLanguages = ["es-ES", "en-US"]
        pedido.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([pedido])
        return (pedido.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    /// Redibuja la imagen con orientación normal y como máximo 2600 px
    /// de lado: las fotos de cámara (12+ MP) hacen lento el OCR sin
    /// mejorar la lectura.
    private static func normalizada(_ imagen: UIImage, ladoMaximo: CGFloat = 2600) -> CGImage? {
        let mayor = max(imagen.size.width, imagen.size.height)
        guard mayor > 0 else { return nil }
        let escala = min(1, ladoMaximo / mayor)
        let tamano = CGSize(
            width: (imagen.size.width * escala).rounded(),
            height: (imagen.size.height * escala).rounded()
        )
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        let render = UIGraphicsImageRenderer(size: tamano, format: formato)
        return render.image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: tamano))
        }.cgImage
    }

    /// Detecta el documento (el papel del ticket) dentro de la foto y
    /// devuelve la imagen recortada y con la perspectiva corregida.
    private static func recorteDeDocumento(en cgImage: CGImage) -> CGImage? {
        let pedido = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([pedido])
        guard let documento = pedido.results?.first, documento.confidence > 0.5 else {
            return nil
        }

        let entrada = CIImage(cgImage: cgImage)
        let ancho = CGFloat(cgImage.width)
        let alto = CGFloat(cgImage.height)
        func punto(_ normalizado: CGPoint) -> CGPoint {
            CGPoint(x: normalizado.x * ancho, y: normalizado.y * alto)
        }

        let filtro = CIFilter.perspectiveCorrection()
        filtro.inputImage = entrada
        filtro.topLeft = punto(documento.topLeft)
        filtro.topRight = punto(documento.topRight)
        filtro.bottomLeft = punto(documento.bottomLeft)
        filtro.bottomRight = punto(documento.bottomRight)

        guard let salida = filtro.outputImage else { return nil }
        return CIContext().createCGImage(salida, from: salida.extent)
    }

    // MARK: - Parser (puro, testeable)

    static func parsear(lineas: [String]) -> DatosTicket {
        DatosTicket(
            monto: detectarTotal(en: lineas),
            nombre: detectarComercio(en: lineas),
            fecha: detectarFecha(en: lineas)
        )
    }

    // MARK: Total

    private struct MontoDetectado {
        let indiceLinea: Int
        let valor: Double
    }

    /// Busca el monto en las líneas que dicen "TOTAL" (el número puede
    /// estar en la misma línea o en la siguiente, porque el OCR suele
    /// separar las columnas). Si no hay, cae al monto más grande del ticket.
    private static func detectarTotal(en lineas: [String]) -> Double? {
        let montos = montosDetectados(en: lineas)
        guard !montos.isEmpty else { return nil }

        let indicesTotal = lineas.indices.filter { indice in
            let mayusculas = lineas[indice].uppercased()
            return mayusculas.contains("TOTAL")
                && !mayusculas.contains("SUBTOTAL")
                && !mayusculas.contains("SUB TOTAL")
                && !mayusculas.contains("SUB-TOTAL")
        }

        // El último "TOTAL" del ticket es el definitivo.
        for indice in indicesTotal.reversed() {
            if let enLinea = montos.filter({ $0.indiceLinea == indice }).map(\.valor).max() {
                return enLinea
            }
            if let siguiente = montos.first(where: { $0.indiceLinea == indice + 1 }) {
                return siguiente.valor
            }
        }

        return montos.map(\.valor).max()
    }

    /// Códigos fiscales y de comprobante: suelen ser números grandes que,
    /// si no se descartan, le ganan al total real en el heurístico de
    /// "el monto más grande del ticket".
    private static let palabrasFiscales = [
        "CUIT", "C.U.I.T", "IIBB", "CAE", "CHK", "PV ", "N°", "NRO",
    ]

    private static func montosDetectados(en lineas: [String]) -> [MontoDetectado] {
        var resultado: [MontoDetectado] = []
        for (indice, linea) in lineas.enumerated() {
            let mayusculas = linea.uppercased()
            if palabrasFiscales.contains(where: { mayusculas.contains($0) }) { continue }

            for coincidencia in linea.matches(of: /\$?\d[\d.,]*\d|\$?\d/) {
                let token = String(coincidencia.output)
                let digitos = token.filter(\.isNumber).count
                guard digitos <= 10 else { continue }
                guard let valor = numero(desde: token), valor >= 1 else { continue }
                resultado.append(MontoDetectado(indiceLinea: indice, valor: valor))
            }
        }
        return resultado
    }

    /// Convierte un token numérico a Double soportando "1.234,56" (AR),
    /// "1,234.56" (US) y enteros con o sin separador de miles.
    static func numero(desde token: String) -> Double? {
        var texto = token
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !texto.isEmpty else { return nil }

        let puntos = texto.filter { $0 == "." }.count
        let comas = texto.filter { $0 == "," }.count

        if puntos > 0 && comas > 0 {
            // El separador que aparece último es el decimal.
            if let ultimaComa = texto.lastIndex(of: ","),
               let ultimoPunto = texto.lastIndex(of: "."),
               ultimaComa > ultimoPunto {
                texto = texto.replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            } else {
                texto = texto.replacingOccurrences(of: ",", with: "")
            }
        } else if comas == 1 {
            let decimales = texto.split(separator: ",", omittingEmptySubsequences: false).last?.count ?? 0
            texto = decimales == 2
                ? texto.replacingOccurrences(of: ",", with: ".")
                : texto.replacingOccurrences(of: ",", with: "")
        } else if comas > 1 {
            texto = texto.replacingOccurrences(of: ",", with: "")
        } else if puntos == 1 {
            let decimales = texto.split(separator: ".", omittingEmptySubsequences: false).last?.count ?? 0
            if decimales != 2 {
                texto = texto.replacingOccurrences(of: ".", with: "")
            }
        } else if puntos > 1 {
            texto = texto.replacingOccurrences(of: ".", with: "")
        }

        return Double(texto)
    }

    // MARK: Comercio

    /// El nombre del comercio suele ser la primera línea "con palabras"
    /// del ticket, salteando encabezados fiscales.
    private static func detectarComercio(en lineas: [String]) -> String? {
        let prohibidas = [
            "TICKET", "FACTURA", "CUIT", "C.U.I.T", "IVA", "CONSUMIDOR",
            "RESPONSABLE", "FECHA", "HORA", "TEL", "COMPROBANTE",
            "ORIGINAL", "DUPLICADO", "P.V", "PV:", "NRO", "N°"
        ]
        for linea in lineas.prefix(5) {
            let limpia = linea.trimmingCharacters(in: .whitespaces)
            guard limpia.filter(\.isLetter).count >= 3 else { continue }
            let mayusculas = limpia.uppercased()
            if prohibidas.contains(where: { mayusculas.contains($0) }) { continue }
            return NombreComercio.limpiar(limpia)
        }
        return nil
    }

    // MARK: Fecha

    /// Primera fecha dd/mm/aaaa (o dd-mm-aa) razonable: ni futura ni de
    /// hace más de dos años.
    private static func detectarFecha(en lineas: [String]) -> Date? {
        let calendario = Calendar.current
        for linea in lineas {
            for coincidencia in linea.matches(of: /(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})/) {
                guard let dia = Int(coincidencia.output.1),
                      let mes = Int(coincidencia.output.2),
                      var anio = Int(coincidencia.output.3),
                      (1...31).contains(dia), (1...12).contains(mes)
                else { continue }
                if anio < 100 { anio += 2000 }

                guard let fecha = calendario.date(from: DateComponents(year: anio, month: mes, day: dia))
                else { continue }
                let limiteViejo = calendario.date(byAdding: .year, value: -2, to: .now) ?? .distantPast
                let limiteFuturo = calendario.date(byAdding: .day, value: 1, to: .now) ?? .distantFuture
                if fecha >= limiteViejo && fecha <= limiteFuturo {
                    return fecha
                }
            }
        }
        return nil
    }

}
