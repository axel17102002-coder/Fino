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
        /// Cada producto del ticket con su precio. Vacío si no se pudo
        /// separar el detalle (no todos los tickets lo permiten).
        var items: [ItemTicket] = []

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
            fecha: detectarFecha(en: lineas),
            items: detectarItems(en: lineas)
        )
    }

    // MARK: Detalle (renglones del ticket)

    /// Separa los productos del ticket con su precio.
    ///
    /// No hay un juego de reglas que sirva para todos los tickets: unos
    /// imprimen los precios con centavos y otros enteros, unos ponen el
    /// gramaje en el nombre y otros no, y Vision a veces devuelve el
    /// renglón entero y a veces la columna de nombres separada de la de
    /// precios. Así que se leen con varias reglas, de la más estricta a
    /// la más permisiva, y **gana la lectura cuyos renglones suman lo
    /// mismo que el total (o el subtotal) impreso**.
    ///
    /// Tener ese número contra el cual validar es lo que permite aflojar
    /// las reglas sin arriesgarse a inventar productos: si al aflojarlas
    /// se cuela una línea que no era un producto, la suma deja de cerrar
    /// y esa lectura queda descartada sola. Si ninguna cuadra, se
    /// devuelve la más estricta, que es la que menos basura mete.
    static func detectarItems(en lineas: [String]) -> [ItemTicket] {
        let referencias = referenciasParaValidar(lineas)
        var mejor: [ItemTicket]?
        for reglas in variantesDeLectura {
            let lectura = items(en: lineas, con: reglas)
            guard !lectura.isEmpty, cuadraConElTicket(lectura, referencias: referencias) else { continue }
            if lectura.count > (mejor?.count ?? 0) { mejor = lectura }
        }
        if let mejor { return conDescuentos(mejor, en: lineas) }

        // Ninguna lectura cierra con un importe impreso. Solo se deja
        // pasar la más conservadora —la que pide centavos y descarta todo
        // lo dudoso—: las permisivas sin validar sacan renglones de la
        // dirección del local o del número de comprobante, y eso es peor
        // que no mostrar detalle.
        return items(en: lineas, con: variantesDeLectura[0])
    }

    /// Cierra el detalle contra lo que se pagó agregándole el descuento.
    ///
    /// Los renglones de un ticket con promociones suman el precio de
    /// lista, no lo que salió: los productos de Carrefour dan 22.064 y el
    /// gasto es 19.431,70. Sin este renglón el detalle no cerraría con el
    /// monto del movimiento y el formulario avisaría de un error que no
    /// existe, justo en los tickets que se leyeron bien.
    ///
    /// El importe sale de restar, no de leer la palabra "AHORRO": la
    /// diferencia entre lo que suman los productos y el total impreso *es*
    /// el descuento, y así no depende de que ese rótulo se lea bien.
    private static func conDescuentos(_ items: [ItemTicket], en lineas: [String]) -> [ItemTicket] {
        guard let total = detectarTotal(en: lineas) else { return items }
        let descuento = total - items.total
        guard descuento < -1 else { return items }
        return items + [ItemTicket(nombre: String(localized: "Descuentos"), monto: descuento)]
    }

    /// Importes contra los que puede cerrar la suma de los renglones.
    ///
    /// El total y el subtotal son los obvios. Se agregan además los demás
    /// importes impresos que sean mayores o iguales al total, porque con
    /// descuentos el detalle suma más que el total y ese número —el
    /// "subtotal sin descuentos"— no siempre queda rotulado de forma
    /// legible. Que tenga que coincidir con un número impreso al centavo
    /// es lo que sigue haciendo de esto una validación y no un permiso.
    private static func referenciasParaValidar(_ lineas: [String]) -> [Double] {
        let total = detectarTotal(en: lineas)
        var referencias = [total, detectarSubtotal(en: lineas)].compactMap { $0 }
        if let total {
            referencias += montosDetectados(en: lineas)
                .filter { $0.conCentavos && $0.valor >= total }
                .map(\.valor)
        }
        return referencias
    }

    /// Los renglones suman lo mismo que algún importe impreso, con un peso
    /// de tolerancia por redondeos.
    private static func cuadraConElTicket(_ items: [ItemTicket], referencias: [Double]) -> Bool {
        let suma = items.total
        return referencias.contains { abs(suma - $0) < 1 }
    }

    /// Reglas con las que se intenta leer el detalle, de la más estricta a
    /// la más permisiva.
    private struct ReglasItems {
        var exigeCentavos = true
        var descartaPalabrasAmbiguas = true
        var nombresSinNumeros = true
    }

    private static let variantesDeLectura: [ReglasItems] = [
        ReglasItems(),
        ReglasItems(descartaPalabrasAmbiguas: false),
        ReglasItems(exigeCentavos: false),
        ReglasItems(exigeCentavos: false, descartaPalabrasAmbiguas: false),
        ReglasItems(nombresSinNumeros: false),
        ReglasItems(exigeCentavos: false, descartaPalabrasAmbiguas: false, nombresSinNumeros: false),
    ]

    private static func items(en lineas: [String], con reglas: ReglasItems) -> [ItemTicket] {
        // Primero el formato "cantidad x precio", que es inconfundible:
        // si el ticket lo usa, no hay por qué probar nada más.
        let porCantidad = itemsPorCantidadYPrecio(lineas, reglas: reglas)
        if !porCantidad.isEmpty { return porCantidad }
        let enRenglon = itemsEnMismoRenglon(lineas, reglas: reglas)
        if !enRenglon.isEmpty { return enRenglon }
        let enColumnas = itemsEnColumnas(lineas, reglas: reglas)
        if !enColumnas.isEmpty { return enColumnas }
        return itemsIntercalados(lineas, reglas: reglas)
    }

    /// Tickets que imprimen el precio en un renglón aparte con la
    /// cantidad: `CARAMELOS BUTTER TOFFES` / `1 x 1659,00`. El nombre es
    /// la línea con letras más cercana hacia arriba, salteando el IVA y
    /// el código de barras, y el importe del renglón es cantidad × precio
    /// unitario.
    private static func itemsPorCantidadYPrecio(_ lineas: [String], reglas: ReglasItems) -> [ItemTicket] {
        var items: [ItemTicket] = []
        for (indice, linea) in lineas.enumerated() {
            guard let partes = cantidadPorPrecio(linea),
                  let unitario = precioValido(partes.precio)
            else { continue }
            let cantidad = partes.cantidad

            var atras = indice - 1
            while atras >= 0, !esNombreCercano(lineas[atras], reglas: reglas) { atras -= 1 }
            guard atras >= 0 else { continue }
            let nombre = limpiarNombreDeItem(lineas[atras])
            guard nombre.count >= 3 else { continue }
            items.append(ItemTicket(nombre: nombre, monto: Double(cantidad) * unitario))
        }
        return items.count >= 2 ? items : []
    }

    /// Precio de una línea que es solo un número, respetando la regla de
    /// centavos de la variante en curso.
    private static func precioDeLinea(_ linea: String, reglas: ReglasItems) -> Double? {
        let limpia = linea.trimmingCharacters(in: .whitespaces)
        if reglas.exigeCentavos, !limpia.contains(/[.,]\d{2}$/) { return nil }
        return precioValido(limpia)
    }

    /// Descompone un renglón "2 x 1689,00" en cantidad y precio unitario.
    ///
    /// Tolera lo que el ticket cuelga después del precio —la alícuota de
    /// IVA, la promo— porque no siempre viene en su propia línea: según
    /// la foto, Vision devuelve "1 x 3300,00" o "1 x 3300,00 (21.00%)" o
    /// "2 x 4025,00 (21.00%)-[16/56%]". Exigiendo la línea entera, esos
    /// renglones dejaban de reconocerse y el detalle salía de la columna
    /// de totales, que da cualquier cosa.
    private static func cantidadPorPrecio(_ linea: String) -> (cantidad: Int, precio: String)? {
        let limpia = linea.trimmingCharacters(in: .whitespaces)
        guard let partes = limpia.prefixMatch(of: /(\d{1,3})\s*[xX×]\s*([\d.,]*\d)\s*(\(|-\[|$)/),
              let cantidad = Int(partes.1),
              cantidad >= 1, cantidad <= 999
        else { return nil }
        return (cantidad, String(partes.2))
    }

    /// La línea es una resta: un descuento o una bonificación.
    /// Contempla los tres guiones que devuelve el OCR según la fuente.
    private static func esResta(_ linea: String) -> Bool {
        let limpia = linea.trimmingCharacters(in: .whitespaces)
        return limpia.hasPrefix("-") || limpia.hasPrefix("\u{2010}") || limpia.hasPrefix("\u{2013}")
    }

    private static func esCantidadPorPrecio(_ linea: String) -> Bool {
        cantidadPorPrecio(linea) != nil
    }

    /// Importe que puede ser un precio. Descarta los códigos de barras,
    /// que también son "solo números" pero tienen 12 o 13 dígitos.
    private static func precioValido(_ token: String) -> Double? {
        guard token.filter(\.isNumber).count <= 9,
              let valor = numero(desde: token),
              valor >= 1, valor < 10_000_000
        else { return nil }
        return valor
    }

    /// Nunca son un producto: encabezado, datos fiscales y totales.
    private static let palabrasQueNuncaSonProducto = [
        "TOTAL", "SUBTOTAL", "IVA", "DESCUENTO", "AHORRO", "BONIFICA", "REDONDEO",
        "CUIT", "C.U.I.T", "IIBB", "CAE", "CHK", "NRO", "N°", "DNI",
        "FACTURA", "COMPROBANTE", "PTO", "CAJERO", "VENDEDOR",
        "ATENDIO", "ATENDIÓ", "SUCURSAL", "DIRECC", "VUELTO",
        "GRACIAS", "CONSUMIDOR", "TRANSPARENCIA", "REGIMEN", "RÉGIMEN",
        "RESPONSABLE", "MONOTRIBUT", "FECHA", "HORA",
        // Encabezados de la tabla de productos: se emparejaban con la
        // cantidad y el precio del primer renglón de verdad.
        "IMPORTE", "DESCRIPCION", "DESCRIPCIÓN", "PRECIO UNIT", "CANT.",
        "TRIBUTO", "IMPUESTO", "CODIGO", "CÓDIGO",
    ]

    /// Rotulan la forma de pago, pero también hay productos que se llaman
    /// así: "TARJETA SUBE", "PAGO FÁCIL". Se descartan solo en las
    /// lecturas estrictas; si la lectura permisiva cierra con el total,
    /// era un producto de verdad.
    private static let palabrasAmbiguas = [
        "TARJETA", "EFECTIVO", "DEBITO", "DÉBITO", "CREDITO", "CRÉDITO",
        "PAGO", "CAMBIO", "CAJA", "TICKET", "TEL",
    ]

    private static func esRenglonDeProducto(_ linea: String, reglas: ReglasItems) -> Bool {
        // Tres letras como mínimo: "[%BI ]" y demás restos de la grilla
        // del ticket tienen una o dos y se colaban como nombre.
        guard linea.count(where: \.isLetter) >= 3 else { return false }
        if contienePalabraClave(linea, entre: palabrasQueNuncaSonProducto) { return false }
        guard reglas.descartaPalabrasAmbiguas else { return true }
        return !contienePalabraClave(linea, entre: palabrasAmbiguas)
    }

    /// ¿Alguna palabra de la línea empieza con alguna de las claves?
    ///
    /// Compara por palabra y no por substring, que es lo que hacía antes:
    /// "IVA" está en la lista y "ACEITE DE OLIVA" la contiene, así que el
    /// hummus dejaba de ser un producto y el nombre terminaba siendo el
    /// rubro de arriba. Es por prefijo para que "BONIFICA" siga tomando
    /// "BONIFICACION" y "MONOTRIBUT" a "MONOTRIBUTISTA". Las claves con
    /// puntos o espacios ("C.U.I.T", "PRECIO UNIT") no se pueden partir en
    /// palabras y se buscan tal cual.
    private static func contienePalabraClave(_ linea: String, entre claves: [String]) -> Bool {
        let mayusculas = linea.uppercased()
        let palabras = mayusculas.split(whereSeparator: { !$0.isLetter })
        return claves.contains { clave in
            clave.contains(where: { !$0.isLetter })
                ? mayusculas.contains(clave)
                : palabras.contains { $0.hasPrefix(clave) }
        }
    }

    /// "LECHE ENTERA 1L        1.850,00" → nombre + precio. El precio es
    /// el último importe del renglón, porque van alineados a la derecha.
    private static func itemsEnMismoRenglon(_ lineas: [String], reglas: ReglasItems) -> [ItemTicket] {
        var items: [ItemTicket] = []
        for original in lineas where esRenglonDeProducto(original, reglas: reglas) {
            // Lo que va entre paréntesis es la alícuota de IVA, nunca el
            // precio. Sin sacarlo, un renglón como
            // "CEREAL BOLITAS CHOCO (21,00)" —que trae el precio en la
            // línea siguiente— entraba como un producto de $21.
            let linea = original.replacing(/\([^)]*\)/, with: " ")
            guard let ultimo = linea.matches(of: /\$?\d[\d.,]*\d|\$?\d/).last else { continue }
            let token = String(ultimo.output)
            if reglas.exigeCentavos, !token.contains(/[.,]\d{2}$/) { continue }
            guard let valor = precioValido(token) else { continue }

            let nombre = limpiarNombreDeItem(String(linea[linea.startIndex..<ultimo.range.lowerBound]))
            guard nombre.count >= 3 else { continue }
            items.append(ItemTicket(nombre: nombre, monto: valor))
        }
        return items
    }

    /// Cuando el OCR devuelve los nombres en bloque y después los precios
    /// en bloque, se emparejan por posición, alineando desde el final de
    /// los nombres: arriba de la lista suele colarse el encabezado del
    /// ticket, que no tiene precio. Pide al menos dos pares para que un
    /// par de líneas sueltas no pase por detalle.
    private static func itemsEnColumnas(_ lineas: [String], reglas: ReglasItems) -> [ItemTicket] {
        var items: [ItemTicket] = []
        var indice = 0
        while indice < lineas.count {
            var nombres: [String] = []
            while indice < lineas.count, esNombreDeProducto(lineas[indice], reglas: reglas) {
                nombres.append(limpiarNombreDeItem(lineas[indice]))
                indice += 1
            }

            var precios: [Double] = []
            while indice < lineas.count,
                  esSoloImporte(lineas[indice]),
                  let valor = precioDeLinea(lineas[indice], reglas: reglas) {
                precios.append(valor)
                indice += 1
            }

            let pares = Swift.min(nombres.count, precios.count)
            if pares >= 2 {
                items += zip(nombres.suffix(pares), precios.prefix(pares))
                    .filter { $0.0.count >= 3 }
                    .map { ItemTicket(nombre: $0.0, monto: $0.1) }
            }
            if nombres.isEmpty && precios.isEmpty { indice += 1 }
        }
        return items
    }

    /// Nombre y precio alternados, un par por renglón del papel. Es la
    /// tercera forma en que llega un ticket: Vision separa las columnas
    /// pero agrupa fila por fila en vez de por bloques.
    private static func itemsIntercalados(_ lineas: [String], reglas: ReglasItems) -> [ItemTicket] {
        var items: [ItemTicket] = []
        var indice = 0
        while indice + 1 < lineas.count {
            guard esNombreDeProducto(lineas[indice], reglas: reglas),
                  esSoloImporte(lineas[indice + 1]),
                  let valor = precioDeLinea(lineas[indice + 1], reglas: reglas)
            else {
                indice += 1
                continue
            }
            let nombre = limpiarNombreDeItem(lineas[indice])
            if nombre.count >= 3 {
                items.append(ItemTicket(nombre: nombre, monto: valor))
            }
            indice += 2
        }
        return items.count >= 2 ? items : []
    }

    /// Nombre del producto al que pertenece un renglón "cantidad x precio":
    /// la línea con letras inmediatamente anterior.
    ///
    /// A diferencia de `esNombreDeProducto`, acá los números **sí** están
    /// permitidos. Aquella regla existe para saber dónde termina la
    /// columna de nombres cuando vienen en bloque; aplicarla también acá
    /// hacía que "QUESO FUNDIDO LIGHT FINLANDIA POTE X 180" se salteara
    /// por el gramaje y el nombre terminara siendo el rubro de arriba
    /// ("Almacen", "Platos Preparados").
    private static func esNombreCercano(_ linea: String, reglas: ReglasItems) -> Bool {
        esRenglonDeProducto(linea, reglas: reglas)
            && !esSoloImporte(linea)
            && !esCantidadPorPrecio(linea)
    }

    /// Línea que puede ser el nombre suelto de un producto: tiene letras,
    /// no es un importe y no está en las listas negras. En las lecturas
    /// estrictas tampoco puede traer números, que es lo que delimita la
    /// columna; aflojarlo permite productos como "COCA 2L".
    private static func esNombreDeProducto(_ linea: String, reglas: ReglasItems) -> Bool {
        guard esRenglonDeProducto(linea, reglas: reglas), !esSoloImporte(linea) else { return false }
        return reglas.nombresSinNumeros ? !linea.contains(where: \.isNumber) : true
    }

    /// Importe rotulado como subtotal. Junto con el total es contra lo que
    /// se valida la suma de los renglones: en un ticket con descuento, el
    /// detalle suma el subtotal y no el total.
    private static func detectarSubtotal(en lineas: [String]) -> Double? {
        let montos = montosDetectados(en: lineas)
        guard !montos.isEmpty else { return nil }

        let indices = lineas.indices.filter { indice in
            lineas[indice].uppercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .contains("SUBTOTAL")
        }
        for indice in indices.reversed() {
            if let enLinea = montos.filter({ $0.indiceLinea == indice }).map(\.valor).max() {
                return enLinea
            }
            if let enColumna = montoEnColumnaAparte(etiqueta: indice, lineas: lineas, montos: montos) {
                return enColumna
            }
        }
        return nil
    }

    private static func limpiarNombreDeItem(_ crudo: String) -> String {
        let sinBordes = crudo
            .replacing(/\([^)]*\)/, with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t.-–—:*$()"))
        return sinBordes
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .capitalized
    }

    // MARK: Total

    private struct MontoDetectado {
        let indiceLinea: Int
        let valor: Double
        /// El token venía con centavos ("16.499,00"). Los importes reales
        /// de un ticket los tienen; los números de ley, de comprobante o
        /// de documento, no.
        let conCentavos: Bool
        /// El importe puede ser el total: vino solo en su línea y no es
        /// una resta.
        ///
        /// Descarta dos cosas que se hacían pasar por total. Los precios
        /// unitarios, que aparecen dos veces —en "1x10.100,00 / 7798126"
        /// y en la columna—: ahí el número no está solo. Y los
        /// descuentos, que también se repiten —en el renglón del producto
        /// y en el desglose— y que el detector lee en positivo porque no
        /// captura el signo.
        let puedeSerTotal: Bool

        init(indiceLinea: Int, valor: Double, puedeSerTotal: Bool, conCentavos: Bool) {
            self.indiceLinea = indiceLinea
            self.valor = valor
            self.puedeSerTotal = puedeSerTotal
            self.conCentavos = conCentavos
        }
    }

    /// Busca el monto en las líneas que dicen "TOTAL" (el número puede
    /// estar en la misma línea o en la siguiente, porque el OCR suele
    /// separar las columnas). Si no hay, cae al monto más grande del ticket.
    private static func detectarTotal(en lineas: [String]) -> Double? {
        let montos = montosDetectados(en: lineas)
        guard !montos.isEmpty else { return nil }

        let indicesTotal = lineas.indices.filter { esLineaDeTotal(lineas[$0]) }

        // El último "TOTAL" del ticket es el definitivo.
        for indice in indicesTotal.reversed() {
            if let enLinea = montos.filter({ $0.indiceLinea == indice }).map(\.valor).max() {
                return contrastado(enLinea, con: montos)
            }
            if let enColumna = montoEnColumnaAparte(etiqueta: indice, lineas: lineas, montos: montos) {
                return contrastado(enColumna, con: montos)
            }
            if let siguiente = montos.first(where: { $0.indiceLinea == indice + 1 }) {
                return contrastado(siguiente.valor, con: montos)
            }
        }

        // Sin un "TOTAL" utilizable —el OCR lo lee "IOTAL" más seguido de
        // lo que uno querría— el mejor indicio es que **el total se
        // repite**: figura en el renglón del total, otra vez en "Suma de
        // sus pagos" y otra en el detalle del pago. El subtotal, en
        // cambio, aparece una sola vez. Así que gana el importe más
        // grande que esté impreso más de una vez.
        if let repetido = importeMasGrandeRepetido(entre: montos) { return repetido }

        // Si tampoco hay repetidos hay que caer al más grande,
        // pero mirando primero los que traen centavos. Vision devuelve las
        // columnas como observaciones sueltas, así que el importe del total
        // no siempre queda pegado a la palabra "TOTAL", y entonces competía
        // contra números que no son plata. Caso real: el "(L. 27743)" de la
        // ley de transparencia fiscal —que figura en todos los tickets
        // argentinos— le ganaba a un total de 16.499,00 por ser más grande.
        let conCentavos = montos.filter(\.conCentavos).map(\.valor)
        if let mejor = conCentavos.max() { return mejor }
        return montos.map(\.valor).max()
    }

    /// Corrige el candidato si hay un importe impreso más de una vez que
    /// sea mayor: ese gana.
    ///
    /// El total se repite en el ticket —en su renglón, otra vez en "Suma
    /// de sus pagos" y otra en el detalle del pago—, así que ningún
    /// importe repetido puede ser mayor que el total. Si lo es, el
    /// candidato salió de una columna mal alineada.
    ///
    /// Caso real: en una foto donde el OCR se comió los signos menos de
    /// los descuentos, la columna del total quedó corrida y devolvía 375
    /// —el primer descuento— en un ticket de 19.431,70, que figura dos
    /// veces impreso.
    private static func contrastado(_ candidato: Double, con montos: [MontoDetectado]) -> Double {
        guard let repetido = importeMasGrandeRepetido(entre: montos), repetido > candidato else {
            return candidato
        }
        return repetido
    }

    /// El importe más grande que aparece impreso más de una vez, mirando
    /// solo los que traen centavos (los que son plata).
    /// Solo cuentan los importes que vinieron **solos** en su línea.
    ///
    /// Un precio unitario aparece dos veces —en "1x10.100,00 / 7798126"
    /// y en la columna— sin ser el total. En un ticket de Disco con 70%
    /// de descuento eso hacía que una mayonesa de 10.100 le ganara al
    /// total real de 4.740: el total puede ser más chico que un producto
    /// cuando la promo es grande. Mirando solo la columna, el precio
    /// unitario figura una vez y deja de competir.
    private static func importeMasGrandeRepetido(entre montos: [MontoDetectado]) -> Double? {
        var veces: [Double: Int] = [:]
        for monto in montos where monto.conCentavos && monto.puedeSerTotal {
            // Redondeado a centavos para que "8775.75" y "8775,75" cuenten
            // como el mismo importe.
            veces[(monto.valor * 100).rounded() / 100, default: 0] += 1
        }
        return veces.filter { $0.value > 1 }.keys.max()
    }

    /// ¿La línea rotula el importe a pagar?
    ///
    /// Se compara sin espacios ni guiones para que "SUBTOTAL", "SUB TOTAL"
    /// y "SUB-TOTAL" caigan todos en el mismo caso: antes cada variante
    /// necesitaba su propia comparación y alcanzaba con que el ticket
    /// usara otra para que el subtotal pasara por total.
    private static func esLineaDeTotal(_ linea: String) -> Bool {
        let compacto = linea.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "–", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: ".", with: "")
        guard compacto.contains("TOTAL"), !compacto.contains("SUBTOTAL") else { return false }
        return !palabrasQueNoSonElImporte.contains { compacto.contains($0) }
    }

    /// Llevan la palabra TOTAL pero no son plata a pagar. Importan porque
    /// suelen ir *después* del total real y, como se toma el último
    /// "TOTAL" del ticket, le ganaban.
    private static let palabrasQueNoSonElImporte = [
        "ITEM", "ARTICULO", "ARTÍCULO", "UNIDAD", "PRODUCTO", "CANT",
        "DESCUENTO", "AHORRO", "BONIFICACION", "BONIFICACIÓN", "IVA",
    ]

    /// Importe que le corresponde a una etiqueta cuando el OCR devolvió
    /// los rótulos y los importes en bloques separados.
    ///
    /// Vision agrupa por columnas, así que un ticket que en el papel dice
    /// `SUBTOTAL 8.300,50 / TOTAL 8.000,00` puede llegar como cuatro
    /// líneas sueltas: `SUBTOTAL`, `TOTAL`, `8.300,50`, `8.000,00`. Ahí el
    /// importe pegado a la palabra TOTAL es el del subtotal, y era el que
    /// se cargaba. La etiqueta y su importe ocupan la misma posición
    /// contando desde el final de cada bloque.
    private static func montoEnColumnaAparte(
        etiqueta indice: Int,
        lineas: [String],
        montos: [MontoDetectado]
    ) -> Double? {
        let conMonto = Set(montos.map(\.indiceLinea))
        guard !conMonto.contains(indice) else { return nil }

        // Bloque contiguo de rótulos sin importe al que pertenece.
        var fin = indice
        while fin + 1 < lineas.count, !conMonto.contains(fin + 1) { fin += 1 }

        // Rótulos de verdad que quedan por debajo de la etiqueta. El "$"
        // suelto que Carrefour imprime arriba de la columna no cuenta:
        // corría un lugar la cuenta y devolvía el importe equivocado.
        let rotulosDebajo = indice < fin
            ? (indice + 1...fin).count(where: { !esSimboloSuelto(lineas[$0]) })
            : 0

        // La columna entera de importes que sigue al bloque. Se toma
        // completa y se cuenta desde abajo, porque arriba de la columna
        // suelen ir los descuentos de los rótulos anteriores.
        var importes: [Double] = []
        var i = fin + 1
        while i < lineas.count {
            if esSimboloSuelto(lineas[i]) { i += 1; continue }
            guard esSoloImporte(lineas[i]), let valor = numero(desde: lineas[i]) else { break }
            importes.append(valor)
            i += 1
        }
        guard !importes.isEmpty else { return nil }

        let posicion = importes.count - 1 - rotulosDebajo
        guard posicion >= 0, importes[posicion] > 0 else { return nil }
        return importes[posicion]
    }

    /// La línea es únicamente un importe (lo que devuelve Vision cuando la
    /// columna de números viene por separado). Acepta el signo menos de
    /// los descuentos: aunque no sirvan como total, ocupan su lugar en la
    /// columna y sacarlos descolocaba la cuenta.
    private static func esSoloImporte(_ linea: String) -> Bool {
        let limpia = linea.trimmingCharacters(in: .whitespaces)
        guard limpia.contains(where: \.isNumber) else { return false }
        return limpia.wholeMatch(of: /-?\$?\s*[\d.,]+/) != nil
    }

    /// Línea que no aporta nada: ni letras ni números. Es el "$" que
    /// algunos tickets imprimen solo, arriba de la columna de importes.
    private static func esSimboloSuelto(_ linea: String) -> Bool {
        !linea.contains(where: { $0.isLetter || $0.isNumber })
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
                resultado.append(MontoDetectado(
                    indiceLinea: indice,
                    valor: valor,
                    puedeSerTotal: esSoloImporte(linea) && !esResta(linea),
                    conCentavos: token.contains(/[.,]\d{2}$/)
                ))
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
