import UIKit

/// Tipos de los Quick Actions del ícono (mantener presionado en la
/// pantalla de inicio). Deben coincidir con el Info.plist.
enum AtajoIcono {
    static let agregarGasto = "com.axelmorano.FinoApp.addExpense"
    static let escanearTicket = "com.axelmorano.FinoApp.scanReceipt"

    /// Traduce el atajo tocado en una señal para la interfaz. UIKit llama
    /// a los métodos de atajos siempre en el hilo principal, así que la
    /// marca queda puesta de inmediato: si fuera asíncrona, en el arranque
    /// en frío la vista podría leerla antes de que se escriba.
    static func manejar(_ item: UIApplicationShortcutItem) {
        MainActor.assumeIsolated {
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
}

/// Los Quick Actions llegan por la escena, no por la app: en apps con
/// escenas (todas las de SwiftUI) iOS ignora los métodos de atajos del
/// app delegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // App abierta desde cero tocando un atajo.
        if let item = options.shortcutItem {
            AtajoIcono.manejar(item)
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/// OJO: este delegate NO debe implementar `scene(_:willConnectTo:)`.
/// Si lo hace, SwiftUI deja de montar su ventana y la app arranca en
/// negro; con solo el método de atajos, SwiftUI sigue armando la interfaz.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        AtajoIcono.manejar(shortcutItem)
        completionHandler(true)
    }
}
