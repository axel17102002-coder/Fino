import Testing
import Foundation
import SwiftData
@testable import Fino

/// Tests de gastos compartidos y redondeo a metas.
@MainActor
struct CompartidosYRedondeoTests {

    // MARK: - Reparto de gastos compartidos

    @Test func parseaNombresSeparadosPorComas() {
        #expect(DeudasService.nombres(desde: "Juan, Ana,  ") == ["Juan", "Ana"])
        #expect(DeudasService.nombres(desde: "") == [])
    }

    @Test func reparteEntreLosNombradosMasVos() {
        // $3.000 entre Juan, Ana y vos → $1.000 cada uno.
        let parte = DeudasService.parteDeCadaUno(total: 3000, nombres: ["Juan", "Ana"])
        #expect(parte == 1000)
    }

    @Test func sinNombresNoHayDeuda() {
        #expect(DeudasService.parteDeCadaUno(total: 3000, nombres: []) == 0)
    }

    @Test func crearGeneraUnaDeudaPorPersona() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let contenedor = try ModelContainer(for: Deuda.self, Movimiento.self, configurations: config)
        let contexto = contenedor.mainContext

        DeudasService.crear(
            conNombres: "Juan, Ana",
            total: 3000,
            detalle: "Cena",
            movimientoID: nil,
            en: contexto
        )

        let deudas = try contexto.fetch(FetchDescriptor<Deuda>())
        #expect(deudas.count == 2)
        #expect(deudas.allSatisfy { $0.monto == 1000 && !$0.saldada })
    }

    @Test func saldarConIngresoRegistraElMovimiento() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let contenedor = try ModelContainer(for: Deuda.self, Movimiento.self, configurations: config)
        let contexto = contenedor.mainContext

        let deuda = Deuda(persona: "Juan", detalle: "Cena", monto: 1000)
        contexto.insert(deuda)

        DeudasService.saldar(deuda, registrandoIngreso: true, en: contexto)

        #expect(deuda.saldada)
        let movimientos = try contexto.fetch(FetchDescriptor<Movimiento>())
        #expect(movimientos.count == 1)
        #expect(movimientos.first?.tipo == .ingreso)
        #expect(movimientos.first?.monto == 1000)
    }

    // MARK: - Redondeo a metas

    @Test func vueltoDelRedondeo() {
        #expect(RedondeoService.vuelto(para: 4320, paso: 1000) == 680)
        #expect(RedondeoService.vuelto(para: 4320, paso: 500) == 180)
        #expect(RedondeoService.vuelto(para: 150, paso: 100) == 50)
    }

    @Test func montoRedondoNoGeneraVuelto() {
        #expect(RedondeoService.vuelto(para: 5000, paso: 1000) == 0)
        #expect(RedondeoService.vuelto(para: 0, paso: 1000) == 0)
        #expect(RedondeoService.vuelto(para: 100, paso: 0) == 0)
    }
}
