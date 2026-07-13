import Foundation
import SwiftData

/// Configura el contenedor de SwiftData y expone operaciones globales
/// sobre la base de datos.
@MainActor
final class PersistenceService {

    static let shared = PersistenceService()

    let container: ModelContainer

    private init() {
        let esquema = Schema([
            Movimiento.self,
            Cuenta.self,
            Presupuesto.self,
            ObjetivoAhorro.self,
            MovimientoRecurrente.self
        ])
        let configuracion = ModelConfiguration(schema: esquema)
        do {
            container = try ModelContainer(for: esquema, configurations: [configuracion])
        } catch {
            // La base existente es de una versión vieja del esquema y no se
            // puede migrar: se descarta y se arranca con una base nueva.
            Self.borrarArchivosDeStore(en: configuracion.url)
            UserDefaults.standard.set(false, forKey: Preferencias.claveDatosDemoCargados)
            do {
                container = try ModelContainer(for: esquema, configurations: [configuracion])
            } catch {
                fatalError("No se pudo crear el ModelContainer: \(error)")
            }
        }
        // Los datos de ejemplo ya no se cargan solos: el onboarding
        // le pregunta al usuario si los quiere.
    }

    /// Borra el archivo de SQLite y sus auxiliares (-shm, -wal).
    private static func borrarArchivosDeStore(en url: URL) {
        let rutas = [url.path, url.path + "-shm", url.path + "-wal"]
        for ruta in rutas {
            try? FileManager.default.removeItem(atPath: ruta)
        }
    }

    /// Elimina todo el contenido de la base de datos.
    func borrarTodo() {
        let contexto = container.mainContext
        try? contexto.delete(model: Movimiento.self)
        try? contexto.delete(model: Cuenta.self)
        try? contexto.delete(model: Presupuesto.self)
        try? contexto.delete(model: ObjetivoAhorro.self)
        try? contexto.delete(model: MovimientoRecurrente.self)
        try? contexto.save()
    }
}
