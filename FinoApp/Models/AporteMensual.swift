import Foundation

/// Un movimiento y lo que aporta al mes que se está mirando.
///
/// Existe porque las dos cosas no coinciden cuando hay cuotas: una compra
/// de 120.000 en 12 aporta 10.000 a cada uno de doce meses. El movimiento
/// conserva su fecha y su monto reales —la lista y el ticket no cambian—
/// y esto es lo que suman los totales.
struct AporteMensual {

    let movimiento: Movimiento
    /// Tu parte de lo que cae en este mes.
    let monto: Double

    var tipo: TipoMovimiento { movimiento.tipo }
    var categoriaRaw: String { movimiento.categoriaRaw }
    var cuenta: Cuenta? { movimiento.cuenta }

    /// Negativo para los gastos, positivo para ingresos y cashback.
    var conSigno: Double { tipo == .gasto ? -monto : monto }
}

extension Array where Element == Movimiento {

    /// Los movimientos como aportes de su monto entero, sin repartir
    /// cuotas. Para los cálculos que no miran un mes en particular y para
    /// los tests que arman el caso a mano.
    var comoAportes: [AporteMensual] {
        map { AporteMensual(movimiento: $0, monto: $0.montoPropio) }
    }
}
