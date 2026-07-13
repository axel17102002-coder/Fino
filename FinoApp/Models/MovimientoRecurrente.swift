import Foundation
import SwiftData

/// Plantilla de un movimiento que se repite todos los meses
/// (suscripciones, alquiler, sueldo, etc.).
@Model
final class MovimientoRecurrente {
    @Attribute(.unique) var id: UUID
    var nombre: String
    var tipoRaw: String
    var categoriaRaw: String
    var monto: Double
    /// Día del mes en que se genera (1 a 31; en meses cortos usa el último día).
    var diaDelMes: Int
    var activo: Bool
    var creado: Date
    /// Fecha del último movimiento generado a partir de esta plantilla.
    var ultimaGenerada: Date?
    var cuenta: Cuenta?

    init(
        nombre: String,
        tipo: TipoMovimiento,
        categoriaRaw: String,
        monto: Double,
        diaDelMes: Int,
        cuenta: Cuenta? = nil
    ) {
        self.id = UUID()
        self.nombre = nombre
        self.tipoRaw = tipo.rawValue
        self.categoriaRaw = categoriaRaw
        self.monto = monto
        self.diaDelMes = min(max(diaDelMes, 1), 31)
        self.activo = true
        self.creado = .now
        self.ultimaGenerada = nil
        self.cuenta = cuenta
    }

    var tipo: TipoMovimiento {
        get { TipoMovimiento(rawValue: tipoRaw) ?? .gasto }
        set { tipoRaw = newValue.rawValue }
    }

    var categoria: (any CategoriaInfo)? {
        tipo.categoria(raw: categoriaRaw) ?? CustomCategoryStore.categoria(raw: categoriaRaw, tipo: tipo)
    }
}
