import Foundation
import SwiftData

/// Exportación e importación de movimientos en formato CSV.
enum ExportImportService {

    private static let encabezado = "tipo,nombre,categoria,monto,fecha,notas,cuenta,cuotas"

    private static var formatterISO: ISO8601DateFormatter { ISO8601DateFormatter() }

    // MARK: - Exportar

    static func csv(de movimientos: [Movimiento]) -> String {
        let iso = formatterISO
        var lineas = [encabezado]
        for movimiento in movimientos.sorted(by: { $0.fecha < $1.fecha }) {
            let campos = [
                movimiento.tipoRaw,
                movimiento.nombre,
                movimiento.categoriaRaw,
                String(movimiento.monto),
                iso.string(from: movimiento.fecha),
                movimiento.notas,
                movimiento.cuenta?.nombre ?? "",
                String(movimiento.cuotas)
            ]
            lineas.append(campos.map(escapar).joined(separator: ","))
        }
        return lineas.joined(separator: "\n")
    }

    /// Escribe el CSV en un archivo temporal y devuelve su URL para compartir.
    static func archivoCSV(de movimientos: [Movimiento]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinanzasApp-movimientos.csv")
        try csv(de: movimientos).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escapar(_ campo: String) -> String {
        guard campo.contains(",") || campo.contains("\"") || campo.contains("\n") else {
            return campo
        }
        return "\"" + campo.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Importar

    /// Importa movimientos desde un CSV con el mismo formato que la exportación.
    /// Devuelve la cantidad de movimientos creados.
    @discardableResult
    static func importarCSV(desde url: URL, en contexto: ModelContext, cuentas: [Cuenta]) -> Int {
        let accesoSeguro = url.startAccessingSecurityScopedResource()
        defer { if accesoSeguro { url.stopAccessingSecurityScopedResource() } }

        guard let contenido = try? String(contentsOf: url, encoding: .utf8) else { return 0 }

        let iso = formatterISO
        var importados = 0
        for campos in parsearCSV(contenido).dropFirst() where campos.count >= 5 {
            guard
                let tipo = TipoMovimiento(rawValue: campos[0]),
                let monto = Double(campos[3]), monto > 0,
                let fecha = iso.date(from: campos[4]),
                !campos[1].isEmpty
            else { continue }

            let cuenta = campos.count > 6 && !campos[6].isEmpty
                ? cuentas.first { $0.nombre == campos[6] }
                : nil
            contexto.insert(Movimiento(
                tipo: tipo,
                nombre: campos[1],
                categoriaRaw: campos[2],
                monto: monto,
                fecha: fecha,
                notas: campos.count > 5 ? campos[5] : "",
                cuotas: campos.count > 7 ? Int(campos[7]) ?? 1 : 1,
                cuenta: cuenta
            ))
            importados += 1
        }
        try? contexto.save()
        return importados
    }

    /// Parser CSV mínimo con soporte de campos entre comillas.
    private static func parsearCSV(_ texto: String) -> [[String]] {
        var filas: [[String]] = []
        var fila: [String] = []
        var campo = ""
        var entreComillas = false

        let caracteres = Array(texto)
        var i = 0
        while i < caracteres.count {
            let caracter = caracteres[i]
            if entreComillas {
                if caracter == "\"" {
                    if i + 1 < caracteres.count && caracteres[i + 1] == "\"" {
                        campo.append("\"")
                        i += 2
                        continue
                    }
                    entreComillas = false
                } else {
                    campo.append(caracter)
                }
            } else {
                switch caracter {
                case "\"":
                    entreComillas = true
                case ",":
                    fila.append(campo)
                    campo = ""
                case "\n", "\r":
                    if !campo.isEmpty || !fila.isEmpty {
                        fila.append(campo)
                        filas.append(fila)
                        campo = ""
                        fila = []
                    }
                default:
                    campo.append(caracter)
                }
            }
            i += 1
        }
        if !campo.isEmpty || !fila.isEmpty {
            fila.append(campo)
            filas.append(fila)
        }
        return filas
    }
}
