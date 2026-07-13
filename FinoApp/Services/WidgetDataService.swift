import Foundation
import WidgetKit

/// Resumen del mes que la app publica para el widget vía App Group.
/// El widget tiene su propia copia de este struct: si cambiás los campos,
/// actualizá también `FinoWidget/FinoWidget.swift`.


/// Publica el resumen del mes en el contenedor compartido y le avisa
/// al widget que se actualice.
enum WidgetDataService {

    static let grupo = "group.com.axelmorano.FinoApp"
    static let clave = "resumenWidget"

    static func publicar(movimientos: [Movimiento]) {
        let delMes = CalculosService.delMes(movimientos)
        let monedaRaw = UserDefaults.standard.string(forKey: Preferencias.claveMoneda) ?? ""
        let resumen = ResumenParaWidget(
            mes: Date.now.mesYAnio,
            balance: CalculosService.balance(delMes),
            gastos: CalculosService.total(delMes, tipo: .gasto),
            ingresos: CalculosService.total(delMes, tipo: .ingreso),
            cashback: CalculosService.total(delMes, tipo: .cashback),
            simboloMoneda: Moneda(rawValue: monedaRaw)?.simbolo ?? "$"
        )
        guard let data = try? JSONEncoder().encode(resumen),
              let compartido = UserDefaults(suiteName: grupo) else { return }
        compartido.set(data, forKey: clave)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
