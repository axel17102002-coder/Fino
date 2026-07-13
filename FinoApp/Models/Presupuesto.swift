import Foundation
import SwiftData

@Model
final class Presupuesto {
    @Attribute(.unique) var id: UUID
    var categoriaRaw: String
    var montoMensual: Double

    init(categoria: CategoriaGasto, montoMensual: Double) {
        self.id = UUID()
        self.categoriaRaw = categoria.rawValue
        self.montoMensual = montoMensual
    }

    var categoria: CategoriaGasto {
        get { CategoriaGasto(rawValue: categoriaRaw) ?? .otros }
        set { categoriaRaw = newValue.rawValue }
    }
}
