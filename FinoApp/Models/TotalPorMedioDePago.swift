import Foundation
import SwiftUI

/// Cuánto se movió con un medio de pago en el mes.
///
/// "Medio de pago" es la cuenta del movimiento: lo que uno piensa es
/// "Visa Galicia" o "Mercado Pago", no la categoría a la que pertenecen.
/// Los movimientos sin cuenta se agrupan aparte en vez de descartarse:
/// esconderlos haría que los totales de la tarjeta no cierren con los del
/// resto de la app.
struct TotalPorMedioDePago: Identifiable, Hashable {

    let id: String
    let nombre: String
    let icono: String
    let color: Color
    /// Plata movida por ese medio en el mes.
    let total: Double
    /// Cantidad de movimientos, que es otra forma de "más usado": se
    /// puede gastar mucho en una sola compra y poco en veinte.
    let cantidad: Int

    /// Reparte los movimientos entre sus cuentas, de mayor a menor.
    ///
    /// Suma la parte propia de los gastos compartidos, igual que el resto
    /// de la app: si pagaste una cena de 100 y te devuelven 50, por esa
    /// tarjeta gastaste 50.
    static func agrupar(_ aportes: [AporteMensual], tipo: TipoMovimiento) -> [TotalPorMedioDePago] {
        let delTipo = aportes.filter { $0.tipo == tipo }
        guard !delTipo.isEmpty else { return [] }

        let porCuenta = Dictionary(grouping: delTipo) { $0.cuenta?.id.uuidString ?? "sin-cuenta" }

        return porCuenta.compactMap { clave, aportes -> TotalPorMedioDePago? in
            let total = aportes.reduce(0) { $0 + $1.monto }
            guard total > 0 else { return nil }
            let cuenta = aportes.first?.cuenta
            return TotalPorMedioDePago(
                id: clave,
                nombre: cuenta?.nombre ?? String(localized: "Sin cuenta"),
                icono: cuenta?.icono ?? "questionmark.circle.fill",
                color: cuenta.map { Color(hex: $0.colorHex) } ?? .gray,
                total: total,
                cantidad: aportes.count
            )
        }
        .sorted { $0.total > $1.total }
    }
}

extension Array where Element == TotalPorMedioDePago {

    var total: Double {
        reduce(0) { $0 + $1.total }
    }

    /// Proporción de un medio sobre el total, para las barras.
    func proporcion(de item: TotalPorMedioDePago) -> Double {
        let total = self.total
        guard total > 0 else { return 0 }
        return item.total / total
    }
}
