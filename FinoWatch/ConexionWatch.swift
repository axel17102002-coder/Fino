import Foundation
import Observation
import WatchConnectivity
import WatchKit
import WidgetKit

/// Estado del reloj: el último snapshot que mandó el iPhone y los gastos
/// que salieron de la muñeca.
///
/// El snapshot se guarda en `UserDefaults` para que la app abra con datos
/// aunque el iPhone esté lejos o apagado. Nunca se muestra una pantalla en
/// blanco por estar esperando la sincro.
@MainActor
@Observable
final class ConexionWatch: NSObject {

    static let shared = ConexionWatch()

    /// El snapshot se guarda en el App Group y no en `UserDefaults.standard`
    /// porque la complicación de la esfera corre en su propio contenedor y
    /// tiene que poder leerlo.
    private static var compartido: UserDefaults {
        UserDefaults(suiteName: PayloadWatch.grupo) ?? .standard
    }

    /// Última foto recibida. `nil` = el reloj todavía no vio nunca al iPhone.
    private(set) var snapshot: SnapshotWatch?

    /// Gastos entregados al sistema que el iPhone todavía no recibió.
    /// Salen de `outstandingUserInfoTransfers`, no de una cola nuestra:
    /// `transferUserInfo` ya persiste y reintenta por su cuenta.
    private(set) var pendientes = 0

    private override init() {
        super.init()
        snapshot = Self.leerGuardado()
    }

    /// Snapshot para dibujar, con valores neutros cuando todavía no llegó
    /// ninguno: así las vistas no repiten el desempaquetado del opcional.
    var datos: SnapshotWatch { snapshot ?? .vacio }

    var hayDatos: Bool { snapshot != nil }

    /// El iPhone está a tiro ahora mismo (app abierta y cerca).
    var alcanzable: Bool {
        WCSession.isSupported() && WCSession.default.isReachable
    }

    // MARK: - Ciclo de vida

    func activar() {
        guard WCSession.isSupported() else { return }
        let sesion = WCSession.default
        sesion.delegate = self
        sesion.activate()
        // Puede haber un contexto esperando desde antes de este arranque.
        aplicar(contexto: sesion.receivedApplicationContext)
        actualizarPendientes()
    }

    // MARK: - Cargar un gasto

    /// Manda el gasto al iPhone y lo suma al snapshot local sin esperar la
    /// vuelta: el usuario ve la dona actualizada al toque y la entrega la
    /// garantiza `transferUserInfo`, no la pantalla.
    func cargar(monto: Double, categoria: SnapshotWatch.CategoriaDisponible) {
        let gasto = GastoDelWatch(
            monto: monto,
            categoriaRaw: categoria.raw,
            nombre: categoria.nombre
        )

        if WCSession.isSupported(), let data = try? JSONEncoder().encode(gasto) {
            WCSession.default.transferUserInfo([PayloadWatch.claveGasto: data])
        }

        aplicarEnLocal(gasto, categoria: categoria)
        actualizarPendientes()
    }

    /// Suma el gasto recién cargado al último snapshot conocido.
    private func aplicarEnLocal(
        _ gasto: GastoDelWatch,
        categoria: SnapshotWatch.CategoriaDisponible
    ) {
        var base = datos
        base.gastos += gasto.monto
        base.balance -= gasto.monto

        if let indice = base.porCategoria.firstIndex(where: { $0.raw == categoria.raw }) {
            let porcion = base.porCategoria[indice]
            base.porCategoria[indice] = SnapshotWatch.PorcionCategoria(
                raw: porcion.raw,
                nombre: porcion.nombre,
                icono: porcion.icono,
                colorHex: porcion.colorHex,
                monto: porcion.monto + gasto.monto
            )
        } else {
            base.porCategoria.append(SnapshotWatch.PorcionCategoria(
                raw: categoria.raw,
                nombre: categoria.nombre,
                icono: categoria.icono,
                colorHex: categoria.colorHex,
                monto: gasto.monto
            ))
        }
        base.porCategoria.sort { $0.monto > $1.monto }

        base.ultimos.insert(
            SnapshotWatch.MovimientoResumido(
                id: gasto.id,
                nombre: gasto.nombre,
                icono: categoria.icono,
                colorHex: categoria.colorHex,
                monto: gasto.monto,
                esGasto: true,
                fecha: gasto.fecha
            ),
            at: 0
        )

        snapshot = base
        guardar(base)
    }

    // MARK: - Persistencia local

    private static func leerGuardado() -> SnapshotWatch? {
        let clave = PayloadWatch.claveSnapshotGuardado
        // Las versiones anteriores guardaban en `standard`, antes de que
        // existiera la complicación: se rescata para no arrancar en blanco
        // después de actualizar.
        let data = compartido.data(forKey: clave)
            ?? UserDefaults.standard.data(forKey: clave)
        guard let data else { return nil }
        return try? JSONDecoder().decode(SnapshotWatch.self, from: data)
    }

    private func guardar(_ snapshot: SnapshotWatch) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        Self.compartido.set(data, forKey: PayloadWatch.claveSnapshotGuardado)
        // La esfera se dibuja aparte: si no se le avisa, sigue mostrando
        // los números viejos hasta que el sistema decida refrescarla.
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func aplicar(contexto: [String: Any]) {
        guard let data = contexto[PayloadWatch.claveSnapshot] as? Data,
              let nuevo = try? JSONDecoder().decode(SnapshotWatch.self, from: data) else { return }
        // Un contexto viejo puede llegar después de uno nuevo si el reloj
        // estuvo dormido: gana siempre el más reciente.
        guard nuevo.generado >= (snapshot?.generado ?? .distantPast) else { return }
        snapshot = nuevo
        guardar(nuevo)
    }

    private func actualizarPendientes() {
        guard WCSession.isSupported() else { return }
        pendientes = WCSession.default.outstandingUserInfoTransfers.count
    }
}

// MARK: - WCSessionDelegate

/// WatchConnectivity llama a estos métodos en su propia cola: cada uno
/// salta al hilo principal para tocar el estado observable.
extension ConexionWatch: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let contexto = session.receivedApplicationContext
        Task { @MainActor in
            aplicar(contexto: contexto)
            actualizarPendientes()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            aplicar(contexto: applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        Task { @MainActor in
            actualizarPendientes()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            actualizarPendientes()
        }
    }
}
