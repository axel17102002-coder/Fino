import Foundation
import SwiftData

/// Lo que una persona te debe por un gasto compartido que pagaste vos.
/// El movimiento original queda con el total (esa plata salió de tu
/// bolsillo); la deuda registra la parte ajena hasta que te la devuelvan.
@Model
final class Deuda {
    @Attribute(.unique) var id: UUID
    var persona: String
    var detalle: String
    var monto: Double
    var fecha: Date
    var saldada: Bool
    /// Gasto que la originó (referencia débil: si borrás el movimiento,
    /// la deuda sigue viva).
    var movimientoID: UUID?

    /// Moneda en la que se pagó el gasto, cuando no es la global.
    /// `monto` siempre queda en la moneda global —así los totales de
    /// "Me deben" suman sin cambios—, y esto guarda con qué te lo tienen
    /// que devolver, que es lo que uno le dice al otro: "me debés 50
    /// dólares", no el equivalente en pesos del día que lo pagaste.
    /// Opcionales para que las bases existentes migren sin drama.
    var monedaOriginalRaw: String?
    var montoOriginal: Double?
    var tasaCambio: Double?

    var monedaOriginal: Moneda? {
        guard let monedaOriginalRaw else { return nil }
        return Moneda(rawValue: monedaOriginalRaw)
    }

    /// La deuda es de un gasto en otra moneda.
    var esMonedaExtranjera: Bool { monedaOriginal != nil }

    /// Monto en la moneda en que se pagó, ej: `US$ 50`.
    var montoOriginalTexto: String? {
        guard let moneda = monedaOriginal, let montoOriginal else { return nil }
        return Formatters.moneda(montoOriginal, moneda: moneda)
    }

    init(
        persona: String,
        detalle: String,
        monto: Double,
        fecha: Date = .now,
        saldada: Bool = false,
        movimientoID: UUID? = nil
    ) {
        self.id = UUID()
        self.persona = persona
        self.detalle = detalle
        self.monto = monto
        self.fecha = fecha
        self.saldada = saldada
        self.movimientoID = movimientoID
        self.monedaOriginalRaw = nil
        self.montoOriginal = nil
        self.tasaCambio = nil
    }
}
