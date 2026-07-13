import Foundation
import SwiftData
import SwiftUI

@Model
final class ObjetivoAhorro {
    @Attribute(.unique) var id: UUID
    var nombre: String
    var icono: String
    var colorHex: String
    var meta: Double
    var ahorrado: Double
    /// Moneda en la que está expresada la meta (puede diferir de la moneda global).
    var monedaRaw: String
    var creado: Date

    init(
        nombre: String,
        icono: String = "star.fill",
        colorHex: String = "0EA5E9",
        meta: Double,
        ahorrado: Double = 0,
        moneda: Moneda = .ars
    ) {
        self.id = UUID()
        self.nombre = nombre
        self.icono = icono
        self.colorHex = colorHex
        self.meta = meta
        self.ahorrado = ahorrado
        self.monedaRaw = moneda.rawValue
        self.creado = .now
    }

    var color: Color { Color(hex: colorHex) }

    var moneda: Moneda {
        get { Moneda(rawValue: monedaRaw) ?? .ars }
        set { monedaRaw = newValue.rawValue }
    }

    var ahorradoFormateado: String { Formatters.moneda(ahorrado, moneda: moneda) }
    var metaFormateada: String { Formatters.moneda(meta, moneda: moneda) }
    var metaFormateadaCompacta: String { Formatters.monedaCompacta(meta, moneda: moneda) }

    /// Progreso del objetivo entre 0 y 1.
    var progreso: Double {
        guard meta > 0 else { return 0 }
        return min(ahorrado / meta, 1)
    }

    var completado: Bool { ahorrado >= meta && meta > 0 }
    var restante: Double { max(meta - ahorrado, 0) }
}
