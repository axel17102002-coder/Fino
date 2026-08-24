import Foundation
import WidgetKit

/// Resumen del mes que la app publica para el widget vía App Group.
/// El widget tiene su propia copia de este struct: si cambiás los campos,
/// actualizá también `FinoWidget/FinoWidget.swift`.


/// Publica el resumen del mes en el contenedor compartido y le avisa
/// al widget que se actualice.
///
/// También es el punto por el que se entera el Apple Watch: el App Group
/// no cruza de dispositivo, así que el reloj se sincroniza aparte
/// (`SincronizacionWatchService`). Colgarlo acá y no de cada alta hace que
/// todo lo que ya refresca el widget refresque también la muñeca.
enum WidgetDataService {

    static let grupo = "group.com.axelmorano.FinoApp"
    static let clave = "resumenWidget"

    @MainActor
    static func publicar(movimientos: [Movimiento]) {
        SincronizacionWatchService.shared.publicar(movimientos: movimientos)

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
