import Testing
import Foundation
import SwiftData
@testable import Fino

/// El backup debe conservar los movimientos recurrentes (versión 2.2).
@MainActor
struct BackupRecurrentesTests {

    @Test func losRecurrentesSobrevivenAlBackup() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let contenedor = try ModelContainer(
            for: Movimiento.self, Cuenta.self, Presupuesto.self,
            ObjetivoAhorro.self, Deuda.self, MovimientoRecurrente.self,
            configurations: config
        )
        let contexto = contenedor.mainContext

        let cuenta = Cuenta(nombre: "Galicia", tipo: .cuentaBancaria)
        contexto.insert(cuenta)
        let netflix = MovimientoRecurrente(
            nombre: "Netflix",
            tipo: .gasto,
            categoriaRaw: CategoriaGasto.suscripciones.rawValue,
            monto: 5000,
            diaDelMes: 10,
            cuenta: cuenta
        )
        netflix.activo = false
        contexto.insert(netflix)
        try contexto.save()

        // Backup y restore sobre el mismo contexto (reemplaza todo).
        let url = try BackupService.crearArchivo(
            cuentas: [cuenta], movimientos: [], presupuestos: [],
            objetivos: [], deudas: [], recurrentes: [netflix]
        )
        _ = BackupService.restaurar(desde: url, en: contexto)

        let restaurados = try contexto.fetch(FetchDescriptor<MovimientoRecurrente>())
        #expect(restaurados.count == 1)
        let r = try #require(restaurados.first)
        #expect(r.nombre == "Netflix")
        #expect(r.monto == 5000)
        #expect(r.diaDelMes == 10)
        #expect(r.activo == false)
        #expect(r.tipo == .gasto)
        // El vínculo con la cuenta se reconstruye.
        #expect(r.cuenta?.nombre == "Galicia")
    }

    @Test func backupViejoSinRecurrentesNoRompe() throws {
        // Un JSON versión 2.1 (sin el campo "recurrentes") se decodifica.
        let json = """
        {
          "version": 2,
          "fecha": "2026-07-01T00:00:00Z",
          "cuentas": [],
          "movimientos": [],
          "presupuestos": [],
          "objetivos": [],
          "categoriasPersonalizadas": [],
          "deudas": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupFino.self, from: Data(json.utf8))
        #expect(backup.recurrentes == nil)
    }
}
