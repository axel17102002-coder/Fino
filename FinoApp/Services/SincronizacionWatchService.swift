import Foundation
import SwiftData
import SwiftUI
import WatchConnectivity

/// Puente con el Apple Watch.
///
/// Va en las dos direcciones:
/// - **iPhone → reloj**: publica un `SnapshotWatch` con el resumen del mes
///   por `updateApplicationContext`. El sistema guarda uno solo por app,
///   así que cada envío pisa al anterior y el reloj siempre lee lo último,
///   incluso si estuvo apagado varios días.
/// - **reloj → iPhone**: recibe los gastos cargados en la muñeca por
///   `transferUserInfo`, que encola en el sistema y entrega aunque la app
///   esté cerrada (iOS la despierta en segundo plano para esto).
///
/// El App Group del widget no sirve para esto: comparte datos entre la app
/// y sus extensiones *en el mismo dispositivo*, y el reloj es otro.
@MainActor
final class SincronizacionWatchService: NSObject {

    static let shared = SincronizacionWatchService()

    /// Ids de los gastos que ya se guardaron. `transferUserInfo` garantiza
    /// la entrega, no que sea exactamente una: sin esta lista, un reintento
    /// del sistema duplicaría el movimiento.
    private static let claveRecibidos = "gastosDelWatchRecibidos"

    /// Último snapshot enviado, para no repetir envíos idénticos.
    private var ultimoSnapshot: SnapshotWatch?

    private override init() { super.init() }

    private var sesion: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    /// Contexto donde se insertan los gastos que llegan del reloj. Se pide
    /// al vuelo (y no se guarda) porque la app puede arrancar en segundo
    /// plano solo para recibir un gasto, sin vista ni entorno montados.
    private var contexto: ModelContext {
        PersistenceService.shared.container.mainContext
    }

    // MARK: - Activación

    /// Arranca la sesión. Se llama desde el `AppDelegate` y no desde una
    /// vista: si la app se despierta en segundo plano para recibir un
    /// gasto, la interfaz puede no montarse nunca.
    func activar() {
        guard let sesion else { return }
        sesion.delegate = self
        sesion.activate()
    }

    // MARK: - iPhone → reloj

    /// Publica el estado actual en el reloj. La llama
    /// `WidgetDataService.publicar`, así que cualquier alta, baja o edición
    /// que ya refresca el widget refresca también la muñeca.
    func publicar(movimientos: [Movimiento]) {
        guard let sesion, sesion.activationState == .activated else { return }
        // Sin reloj emparejado o sin la app instalada no hay a quién avisarle.
        guard sesion.isPaired, sesion.isWatchAppInstalled else { return }

        let snapshot = armarSnapshot(movimientos: movimientos)

        // La hora de armado cambia siempre: se normaliza antes de comparar
        // para que un snapshot idéntico no gaste batería de las dos puntas.
        if var comparable = ultimoSnapshot {
            comparable.generado = snapshot.generado
            guard comparable != snapshot else { return }
        }

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try sesion.updateApplicationContext([PayloadWatch.claveSnapshot: data])
            ultimoSnapshot = snapshot
        } catch {
            // Que no haya reloj escuchando no es una falla de la app.
        }
    }

    private func armarSnapshot(movimientos: [Movimiento]) -> SnapshotWatch {
        let delMes = CalculosService.delMes(movimientos)
        let moneda = Formatters.monedaActual

        let porCategoria = CalculosService.totalesPorCategoria(delMes, tipo: .gasto)
            .map { total in
                SnapshotWatch.PorcionCategoria(
                    raw: total.categoria.rawValue,
                    nombre: total.categoria.nombre,
                    icono: total.categoria.icono,
                    colorHex: Self.hex(de: total.categoria.color),
                    monto: total.total
                )
            }

        let categorias = CustomCategoryStore.categoriasOrdenadas(para: .gasto)
            .map { categoria in
                SnapshotWatch.CategoriaDisponible(
                    raw: categoria.rawValue,
                    nombre: categoria.nombre,
                    icono: categoria.icono,
                    colorHex: Self.hex(de: categoria.color)
                )
            }

        let ultimos = movimientos
            .sorted { $0.fecha > $1.fecha }
            .prefix(15)
            .map { movimiento in
                SnapshotWatch.MovimientoResumido(
                    id: movimiento.id,
                    nombre: movimiento.nombre,
                    icono: movimiento.iconoCategoria,
                    colorHex: movimiento.categoria.map(Self.hex(deCategoria:)) ?? "78716C",
                    monto: movimiento.monto,
                    esGasto: movimiento.tipo == .gasto,
                    fecha: movimiento.fecha
                )
            }

        return SnapshotWatch(
            generado: .now,
            mes: Date.now.mesYAnio,
            simboloMoneda: moneda.simbolo,
            decimales: moneda.decimales,
            montosOcultos: Formatters.montosOcultos,
            gastos: CalculosService.total(delMes, tipo: .gasto),
            ingresos: CalculosService.total(delMes, tipo: .ingreso),
            balance: CalculosService.balance(delMes),
            porCategoria: porCategoria,
            categorias: categorias,
            ultimos: Array(ultimos)
        )
    }

    // MARK: - Reloj → iPhone

    /// Guarda un gasto que llegó de la muñeca y devuelve `true` si era
    /// nuevo. Corre por el mismo camino que el alta rápida del iPhone:
    /// redondeo al objetivo, aviso de presupuesto y refresco del widget.
    @discardableResult
    private func guardar(_ gasto: GastoDelWatch) -> Bool {
        var recibidos = Set(UserDefaults.standard.stringArray(forKey: Self.claveRecibidos) ?? [])
        guard !recibidos.contains(gasto.id.uuidString) else { return false }

        let movimiento = Movimiento(
            tipo: .gasto,
            nombre: gasto.nombre,
            categoriaRaw: gasto.categoriaRaw,
            monto: gasto.monto,
            fecha: gasto.fecha
        )
        contexto.insert(movimiento)
        try? contexto.save()

        recibidos.insert(gasto.id.uuidString)
        // La lista se poda: alcanza con recordar lo reciente para
        // descartar un reintento del sistema.
        UserDefaults.standard.set(Array(recibidos.suffix(200)), forKey: Self.claveRecibidos)

        RedondeoService.aplicar(aGastoDe: gasto.monto, en: contexto)
        NotificacionesService.verificarPresupuestos(en: contexto)

        let movimientos = (try? contexto.fetch(FetchDescriptor<Movimiento>())) ?? []
        WidgetDataService.publicar(movimientos: movimientos)
        return true
    }

    // MARK: - Color a hexadecimal

    /// Las categorías exponen su color como `Color` de SwiftUI, pero al
    /// reloj viaja el hexa. Se resuelve en modo oscuro porque la pantalla
    /// del reloj siempre lo es.
    private static func hex(de color: Color) -> String {
        let traits = UITraitCollection(userInterfaceStyle: .dark)
        let resuelto = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard resuelto.getRed(&r, green: &g, blue: &b, alpha: &a) else { return "78716C" }
        return String(
            format: "%02X%02X%02X",
            Int((r * 255).rounded()),
            Int((g * 255).rounded()),
            Int((b * 255).rounded())
        )
    }

    /// Igual que `hex(de:)` pero para una categoría existencial, que no se
    /// puede pasar directo a `map` por el `any`.
    private static func hex(deCategoria categoria: any CategoriaInfo) -> String {
        hex(de: categoria.color)
    }
}

// MARK: - WCSessionDelegate

/// El delegate es `nonisolated` porque WatchConnectivity llama a sus
/// métodos en una cola propia; cada uno salta al hilo principal para tocar
/// la base y las preferencias.
extension SincronizacionWatchService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            let movimientos = (try? contexto.fetch(FetchDescriptor<Movimiento>())) ?? []
            publicar(movimientos: movimientos)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo[PayloadWatch.claveGasto] as? Data,
              let gasto = try? JSONDecoder().decode(GastoDelWatch.self, from: data) else { return }
        Task { @MainActor in
            guardar(gasto)
        }
    }

    /// El reloj vuelve a publicar su estado cuando se reactiva; también
    /// sirve como pedido de datos frescos apenas queda alcanzable.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in
            let movimientos = (try? contexto.fetch(FetchDescriptor<Movimiento>())) ?? []
            publicar(movimientos: movimientos)
        }
    }

    /// Obligatorios en iOS: el usuario puede cambiar de reloj emparejado en
    /// caliente y hay que reactivar la sesión contra el nuevo.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            // Recién instalada la app del reloj no tiene nada: el snapshot
            // guardado ya no vale como "último enviado".
            ultimoSnapshot = nil
            let movimientos = (try? contexto.fetch(FetchDescriptor<Movimiento>())) ?? []
            publicar(movimientos: movimientos)
        }
    }
}
