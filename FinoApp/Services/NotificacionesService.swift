import Foundation
import SwiftData
import UserNotifications

/// Notificaciones locales: recordatorio de backup y alertas de presupuesto.
@MainActor
enum NotificacionesService {

    private static let idRecordatorioBackup = "recordatorioBackup"

    /// Pide permiso para notificar (el sistema pregunta una sola vez).
    @discardableResult
    static func pedirPermiso() async -> Bool {
        let centro = UNUserNotificationCenter.current()
        return (try? await centro.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Estado del permiso, para que Configuración pueda avisar cuando
    /// las notificaciones están apagadas y todo falla en silencio.
    static func estadoPermiso() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Cantidad de avisos programados (vencimientos + backup).
    static func programadas() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }

    // MARK: - Recordatorio de backup

    /// Programa un recordatorio que se repite cada 15 días.
    static func programarRecordatorioBackup() {
        let contenido = UNMutableNotificationContent()
        contenido.title = String(localized: "Backup de Fino 💾")
        contenido.body = String(localized: "Pasaron 15 días desde el último recordatorio. Guardá un backup en iCloud Drive para no perder tus datos.")
        contenido.sound = .default

        let disparador = UNTimeIntervalNotificationTrigger(
            timeInterval: 15 * 24 * 60 * 60,
            repeats: true
        )
        let pedido = UNNotificationRequest(
            identifier: idRecordatorioBackup,
            content: contenido,
            trigger: disparador
        )
        UNUserNotificationCenter.current().add(pedido)
    }

    static func cancelarRecordatorioBackup() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [idRecordatorioBackup])
    }

    // MARK: - Alertas de presupuesto

    /// Revisa todos los presupuestos y notifica al cruzar el 80% o el 100%
    /// del monto mensual. Cada umbral avisa una sola vez por período.
    static func verificarPresupuestos(en contexto: ModelContext) {
        let presupuestos = (try? contexto.fetch(FetchDescriptor<Presupuesto>())) ?? []
        let movimientos = (try? contexto.fetch(FetchDescriptor<Movimiento>())) ?? []
        guard !presupuestos.isEmpty else { return }

        let inicioPeriodo = Int(CalculosService.inicioPeriodo().timeIntervalSince1970)

        for presupuesto in presupuestos where presupuesto.montoMensual > 0 {
            let gastado = CalculosService.gastado(en: presupuesto.categoria, movimientos: movimientos)
            let fraccion = gastado / presupuesto.montoMensual

            for umbral in [100, 80] where fraccion >= Double(umbral) / 100 {
                let clave = "alertaPresupuesto-\(presupuesto.id.uuidString)-\(inicioPeriodo)-\(umbral)"
                if !UserDefaults.standard.bool(forKey: clave) {
                    UserDefaults.standard.set(true, forKey: clave)
                    avisarPresupuesto(
                        categoria: presupuesto.categoria.nombre,
                        umbral: umbral,
                        gastado: gastado,
                        limite: presupuesto.montoMensual
                    )
                }
                break
            }
        }
    }

    // MARK: - Vencimientos de tarjetas

    /// Programa (o reprograma) el aviso del día anterior a cada
    /// vencimiento de tarjeta, con el consumo actual. Se llama al abrir
    /// la app y al mandarla a background, así el monto queda fresco.
    static func programarVencimientosTarjetas(en contexto: ModelContext) {
        let cuentas = (try? contexto.fetch(FetchDescriptor<Cuenta>())) ?? []
        let tarjetas = cuentas.filter { $0.esTarjetaCredito && $0.diaVencimiento > 0 }
        guard !tarjetas.isEmpty else { return }
        // Sin permiso los avisos se descartan en silencio; pedirlo acá
        // cubre a quien lo saltó en el onboarding y después configuró
        // una tarjeta.
        Task { await pedirPermiso() }

        let centro = UNUserNotificationCenter.current()
        let calendario = Calendar.current

        for tarjeta in tarjetas {
            let id = "vencimiento-\(tarjeta.id.uuidString)"
            centro.removePendingNotificationRequests(withIdentifiers: [id])

            guard let vencimiento = CalculosService.proximaFecha(dia: tarjeta.diaVencimiento),
                  let aviso = calendario.date(byAdding: .day, value: -1, to: vencimiento),
                  aviso >= calendario.startOfDay(for: .now)
            else { continue }

            let consumo = CalculosService.consumoActual(de: tarjeta)
            let contenido = UNMutableNotificationContent()
            contenido.title = String(localized: "Mañana vence la \(tarjeta.nombre) 💳")
            contenido.body = consumo > 0
                ? String(localized: "Consumo actual: \(consumo.enMoneda). No te olvides de pagarla.")
                : String(localized: "No te olvides de revisarla.")
            contenido.sound = .default

            var componentes = calendario.dateComponents([.year, .month, .day], from: aviso)
            componentes.hour = 10
            let pedido = UNNotificationRequest(
                identifier: id,
                content: contenido,
                trigger: UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
            )
            centro.add(pedido)
        }
    }

    private static func avisarPresupuesto(categoria: String, umbral: Int, gastado: Double, limite: Double) {
        Task { await pedirPermiso() }

        let contenido = UNMutableNotificationContent()
        if umbral >= 100 {
            contenido.title = String(localized: "Presupuesto de \(categoria) superado 🔴")
            contenido.body = String(localized: "Llevás gastados \(gastado.enMoneda) de un límite de \(limite.enMoneda).")
        } else {
            let porcentaje = "\(umbral)%"
            contenido.title = String(localized: "Presupuesto de \(categoria) al \(porcentaje) 🟡")
            contenido.body = String(localized: "Llevás \(gastado.enMoneda) de \(limite.enMoneda). Ojo con lo que queda del período.")
        }
        contenido.sound = .default

        let pedido = UNNotificationRequest(
            identifier: "presupuesto-\(categoria)-\(umbral)-\(Date.now.timeIntervalSince1970)",
            content: contenido,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(pedido)
    }
}
