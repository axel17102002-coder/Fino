import Foundation
import SwiftData

/// Predice la categoría de un gasto a partir del historial: si el usuario
/// ya categorizó gastos con ese nombre, se usa su categoría más frecuente.
/// Consulta el historial en vivo, así cada corrección del usuario mejora
/// la próxima predicción sin entrenar nada.
@MainActor
enum CategoriaPredictorService {

    /// Categoría más probable para un gasto con este nombre, o `nil` si
    /// el historial no dice nada.
    static func categoria(paraGasto nombre: String, en contexto: ModelContext) -> String? {
        let movimientos = (try? contexto.fetch(FetchDescriptor<Movimiento>())) ?? []
        return predecir(nombre: nombre, entre: movimientos)
    }

    /// Parte pura y testeable: elige la categoría más usada entre los
    /// gastos de nombre parecido. Empates: gana la más reciente.
    static func predecir(nombre: String, entre movimientos: [Movimiento]) -> String? {
        let buscado = normalizar(nombre)
        guard buscado.count >= 3 else { return nil }

        let parecidos = movimientos.filter { movimiento in
            guard movimiento.tipo == .gasto else { return false }
            let candidato = normalizar(movimiento.nombre)
            return candidato == buscado
                || candidato.hasPrefix(buscado)
                || buscado.hasPrefix(candidato)
        }
        guard !parecidos.isEmpty else { return nil }

        let porCategoria = Dictionary(grouping: parecidos, by: \.categoriaRaw)
        return porCategoria.max { a, b in
            if a.value.count != b.value.count {
                return a.value.count < b.value.count
            }
            let ultimaA = a.value.map(\.fecha).max() ?? .distantPast
            let ultimaB = b.value.map(\.fecha).max() ?? .distantPast
            return ultimaA < ultimaB
        }?.key
    }

    private static func normalizar(_ texto: String) -> String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .lowercased()
    }
}
