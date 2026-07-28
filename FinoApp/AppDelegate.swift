import UIKit
import UserNotifications

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
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Puesto acá (y no en la escena) para capturar también el toque
        // en una notificación que arranca la app desde cero.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

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

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Deep-link de la notificación "Revisá la categoría": abre ese
    /// movimiento en el formulario de edición apenas la app está en pantalla.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let idTexto = response.notification.request.content.userInfo["movimientoId"] as? String,
           let id = UUID(uuidString: idTexto) {
            MainActor.assumeIsolated {
                AccionesRapidas.shared.movimientoIdParaCategorizar = id
            }
        }
        completionHandler()
    }

    /// El sistema silencia las notificaciones con la app en primer plano
    /// salvo que el delegate pida explícitamente mostrarlas.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
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
