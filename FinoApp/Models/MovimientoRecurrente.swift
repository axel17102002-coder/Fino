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

    /// Moneda en la que está expresado `monto`, cuando no es la global.
    /// `nil` = la plantilla está en la moneda de la app.
    ///
    /// A diferencia de un movimiento suelto, acá **no** se guarda el monto
    /// convertido: una suscripción de USD 12,99 vale distinto cada mes, y
    /// lo que se repite es el precio en dólares. La conversión se hace al
    /// generar cada movimiento, con la cotización de ese día.
    /// Opcional para que las bases existentes migren sin drama.
    var monedaOriginalRaw: String?

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
        self.monedaOriginalRaw = nil
    }

    var tipo: TipoMovimiento {
        get { TipoMovimiento(rawValue: tipoRaw) ?? .gasto }
        set { tipoRaw = newValue.rawValue }
    }

    /// Moneda del monto. Sin moneda propia, la global de la app.
    var moneda: Moneda {
        get { monedaOriginalRaw.flatMap(Moneda.init(rawValue:)) ?? Formatters.monedaActual }
        set { monedaOriginalRaw = newValue == Formatters.monedaActual ? nil : newValue.rawValue }
    }

    /// La plantilla está en una moneda distinta a la de la app y hay que
    /// convertirla al generar cada movimiento.
    var necesitaConversion: Bool {
        monedaOriginalRaw != nil && moneda != Formatters.monedaActual
    }

    var categoria: (any CategoriaInfo)? {
        tipo.categoria(raw: categoriaRaw) ?? CustomCategoryStore.categoria(raw: categoriaRaw, tipo: tipo)
    }
}
