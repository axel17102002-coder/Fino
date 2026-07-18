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

    @Test func partesDesigualesCreanDeudasConSuMonto() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let contenedor = try ModelContainer(for: Deuda.self, Movimiento.self, configurations: config)
        let contexto = contenedor.mainContext

        DeudasService.crear(
            partes: [("Juan", 2000), ("Ana", 500), ("Pedro", 0)],
            detalle: "Asado",
            movimientoID: nil,
            en: contexto
        )

        let deudas = try contexto.fetch(FetchDescriptor<Deuda>())
        #expect(deudas.count == 2)
        #expect(deudas.first { $0.persona == "Juan" }?.monto == 2000)
        #expect(deudas.first { $0.persona == "Ana" }?.monto == 500)
    }

    @Test func borrarElGastoBorraSusDeudas() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let contenedor = try ModelContainer(for: Deuda.self, Movimiento.self, configurations: config)
        let contexto = contenedor.mainContext

        let gasto = Movimiento(
            tipo: .gasto, nombre: "Cena",
            categoriaRaw: CategoriaGasto.comida.rawValue, monto: 3000
        )
        contexto.insert(gasto)
        DeudasService.crear(
            conNombres: "Juan, Ana", total: 3000, detalle: "Cena",
            movimientoID: gasto.id, en: contexto
        )
        // Una deuda de otro gasto no se debe tocar.
        contexto.insert(Deuda(persona: "Pedro", detalle: "Otra cosa", monto: 500))

        DeudasService.eliminarVinculadas(a: gasto.id, en: contexto)

        let restantes = try contexto.fetch(FetchDescriptor<Deuda>())
        #expect(restantes.count == 1)
        #expect(restantes.first?.persona == "Pedro")
    }

    // MARK: - Consumo propio

    @Test func elGastoCompartidoCuentaSoloTuParte() {
        // Pagaste 3 vuelos ($104), tu parte es $34.
        let vuelos = movimientoConAjeno(.gasto, monto: 104, ajeno: 70)
        #expect(vuelos.montoPropio == 34)
        #expect(CalculosService.total([vuelos], tipo: .gasto) == 34)
        // La plata que salió sigue completa (para el saldo de la cuenta).
        #expect(vuelos.montoConSigno == -104)
    }

    @Test func laDevolucionNoInflaLosIngresos() {
        let sueldo = movimientoConAjeno(.ingreso, monto: 1000, ajeno: nil)
        let devolucion = movimientoConAjeno(.ingreso, monto: 70, ajeno: 70)
        #expect(CalculosService.total([sueldo, devolucion], tipo: .ingreso) == 1000)
        // Pero sí suma al flujo real de plata.
        #expect(devolucion.montoConSigno == 70)
    }

    @Test func balanceDelMesUsaConsumoPropio() {
        let movimientos = [
            movimientoConAjeno(.ingreso, monto: 1000, ajeno: nil),
            movimientoConAjeno(.gasto, monto: 104, ajeno: 70),   // tu parte 34
            movimientoConAjeno(.ingreso, monto: 70, ajeno: 70),  // devolución
        ]
        #expect(CalculosService.balance(movimientos) == 966)
    }

    private func movimientoConAjeno(_ tipo: TipoMovimiento, monto: Double, ajeno: Double?) -> Movimiento {
        let movimiento = Movimiento(
            tipo: tipo, nombre: "Test",
            categoriaRaw: tipo == .gasto ? CategoriaGasto.viajes.rawValue : CategoriaIngreso.otros.rawValue,
            monto: monto
        )
        movimiento.montoAjeno = ajeno
        return movimiento
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
