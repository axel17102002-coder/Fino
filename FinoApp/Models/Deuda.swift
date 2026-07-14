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
    }
}
