import Foundation

/// Un resumen de tarjeta: el ciclo que cierra en `cierre`, lo que entra y
/// cuánto suma.
///
/// Agrupar por resumen y no por día es lo que hace entendible que una
/// compra del 28 pese el mes que viene: la ves adentro del resumen que le
/// corresponde, junto a las cuotas de compras viejas que caen ahí.
struct ResumenDeTarjeta: Identifiable {

    /// Fecha en que cierra este resumen.
    let cierre: Date
    /// Cada movimiento con lo que aporta a **este** resumen: el importe
    /// entero si fue un pago único, o la cuota que toca si está
    /// financiado.
    let renglones: [Renglon]

    var id: Date { cierre }

    var total: Double {
        renglones.reduce(0) { $0 + $1.monto }
    }

    struct Renglon: Identifiable {
        let movimiento: Movimiento
        let monto: Double
        /// Qué cuota de cuántas cae en este resumen, si está financiado.
        let cuota: Int?

        var id: String {
            "\(movimiento.id.uuidString)-\(cuota ?? 0)"
        }
    }

    /// Título del resumen, por el mes en que cierra.
    var titulo: String {
        cierre.formatted(.dateTime.month(.wide).year())
    }

    /// Todavía no cerró: es el que se está acumulando.
    var enCurso: Bool { cierre > .now }
}
