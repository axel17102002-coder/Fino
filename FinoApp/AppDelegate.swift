import UIKit

/// Tipos de los Quick Actions del ícono (mantener presionado en la
/// pantalla de inicio). Deben coincidir con el Info.plist.
enum AtajoIcono {
    static let agregarGasto = "com.axelmorano.FinoApp.addExpense"
    static let escanearTicket = "com.axelmorano.FinoApp.scanReceipt"

    /// Traduce el atajo tocado en una señal para la interfaz.
    @MainActor
    static func manejar(_ item: UIApplicationShortcutItem) {
        switch item.type {
        case agregarGasto:
            AccionesRapidas.shared.abrirAltaMovimiento = true
        case escanearTicket:
            AccionesRapidas.shared.escanearTicket = true
        default:
            break
        }
    }
}

/// Recibe los Quick Actions del ícono sin tocar el manejo de escenas de
/// SwiftUI (implementar `configurationForConnecting` o poner un scene
/// delegate propio deja la pantalla en negro).
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Arranque en frío desde un atajo: el ícono viene en las opciones de
    /// lanzamiento.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            Task { @MainActor in AtajoIcono.manejar(item) }
        }
        return true
    }

    /// App ya abierta (en segundo plano) y se toca un atajo.
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in AtajoIcono.manejar(shortcutItem) }
        completionHandler(true)
    }
}
