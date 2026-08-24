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

/// Gastos compartidos cargados en otra moneda.
@Suite(.serialized)
struct CompartidosEnOtraMonedaTests {

    @MainActor
    private func contexto() throws -> ModelContext {
        let contenedor = try ModelContainer(
            for: Movimiento.self, Cuenta.self, Deuda.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(contenedor)
    }

    @MainActor
    @Test func laDeudaGuardaLasDosMonedas() throws {
        let contexto = try contexto()
        // Cena de US$ 90 pagada por vos, a dividir con dos amigos: US$ 30
        // a cada uno, con el dólar a 1.200.
        DeudasService.crear(
            partes: [("Juan", 30), ("Ana", 30)],
            detalle: "Cena",
            movimientoID: nil,
            moneda: .usd,
            tasa: 1_200,
            en: contexto
        )

        let deudas = try contexto.fetch(FetchDescriptor<Deuda>())
        #expect(deudas.count == 2)
        let juan = try #require(deudas.first { $0.persona == "Juan" })
        // Te debe 30 dólares, que hoy son 36.000 pesos.
        #expect(juan.montoOriginal == 30)
        #expect(juan.monedaOriginal == .usd)
        #expect(juan.monto == 36_000)
    }

    @MainActor
    @Test func sinMonedaExtranjeraNoGuardaOriginal() throws {
        let contexto = try contexto()
        DeudasService.crear(
            partes: [("Juan", 5_000)],
            detalle: "Asado",
            movimientoID: nil,
            en: contexto
        )
        let deuda = try #require(try contexto.fetch(FetchDescriptor<Deuda>()).first)
        #expect(deuda.monto == 5_000)
        #expect(deuda.montoOriginal == nil)
        #expect(!deuda.esMonedaExtranjera)
    }

    @Test func laParteAjenaDelGastoQuedaEnLaMonedaGlobal() {
        // El bug: el movimiento guarda 108.000 pesos (90 dólares a 1.200)
        // y la parte ajena se guardaba en dólares, así que "tu parte"
        // daba 108.000 − 60 = 107.940 en vez de 36.000.
        let movimiento = Movimiento(
            tipo: .gasto,
            nombre: "Cena",
            categoriaRaw: CategoriaGasto.comida.rawValue,
            monto: 108_000
        )
        movimiento.montoAjeno = 60 * 1_200
        #expect(movimiento.montoPropio == 36_000)
    }
}

/// Reparto de un gasto compartido usando los renglones del ticket.
struct RepartoPorRenglonesTests {

    private let compra: [ItemTicket] = [
        ItemTicket(nombre: "Fideos", monto: 2_000),
        ItemTicket(nombre: "Salsa", monto: 1_000),
        // El shampoo lo usás solo vos.
        ItemTicket(nombre: "Shampoo", monto: 3_000, soloMio: true),
    ]

    @Test func loMarcadoComoTuyoNoSeDivide() {
        // 3.000 compartidos entre dos personas: 1.500 cada uno. Los 3.000
        // del shampoo son todos tuyos, así que tu parte es 4.500.
        let reparto = compra.reparto(entrePersonas: 1, totalPagado: 6_000)
        #expect(reparto?.deCadaUno == 1_500)
        #expect(reparto?.tuya == 4_500)
    }

    @Test func sinNadaMarcadoEsUnaDivisionComun() {
        let todosCompartidos = compra.map { ItemTicket(nombre: $0.nombre, monto: $0.monto) }
        let reparto = todosCompartidos.reparto(entrePersonas: 1, totalPagado: 6_000)
        #expect(reparto?.deCadaUno == 3_000)
        #expect(reparto?.tuya == 3_000)
    }

    @Test func elDescuentoDelTicketSeRepartePorProporcion() {
        // Los renglones suman 6.000 pero se pagaron 5.400 por una promo.
        // El reparto se escala: cada parte baja un 10%.
        let reparto = compra.reparto(entrePersonas: 1, totalPagado: 5_400)
        #expect(reparto?.deCadaUno == 1_350)
        #expect(reparto?.tuya == 4_050)
        // Y lo repartido suma exactamente lo que se pagó.
        #expect((reparto?.tuya ?? 0) + (reparto?.deCadaUno ?? 0) == 5_400)
    }

    @Test func repartoEntreTresPersonas() {
        let reparto = compra.reparto(entrePersonas: 2, totalPagado: 6_000)
        #expect(reparto?.deCadaUno == 1_000)
        #expect(reparto?.tuya == 4_000)
    }

    @Test func sinPersonasNoHayReparto() {
        #expect(compra.reparto(entrePersonas: 0, totalPagado: 6_000) == nil)
    }

    @Test func elDetalleViejoSeLeeSinLaMarca() throws {
        // Los detalles guardados antes de que existiera `soloMio` no traen
        // la clave; tienen que decodificar igual.
        let json = Data(#"[{"nombre":"Pan","monto":1500}]"#.utf8)
        let items = try JSONDecoder().decode([ItemTicket].self, from: json)
        #expect(items.first?.soloMio == false)
        #expect(items.first?.monto == 1_500)
    }
}

/// Cashback cargado junto con el gasto, por porcentaje o por monto.
struct CashbackDelGastoTests {

    @Test func porcentajeSobreElGasto() {
        var cashback = CashbackDelGasto(modo: .porcentaje, texto: "20")
        #expect(cashback.monto(sobre: 10_000) == 2_000)
        cashback.texto = "7,5"
        #expect(cashback.monto(sobre: 10_000) == 750)
    }

    @Test func montoFijo() {
        let cashback = CashbackDelGasto(modo: .monto, texto: "1500")
        #expect(cashback.monto(sobre: 10_000) == 1_500)
    }

    @Test func noPuedeVolverMasDeLoQueGastaste() {
        // Un monto mayor al gasto sería una ganancia, no un reintegro:
        // casi seguro es un error de tipeo y se recorta al gasto.
        let cashback = CashbackDelGasto(modo: .monto, texto: "99999")
        #expect(cashback.monto(sobre: 10_000) == 10_000)
    }

    @Test func elPorcentajeNoPasaDeCien() {
        let cashback = CashbackDelGasto(modo: .porcentaje, texto: "150")
        #expect(cashback.monto(sobre: 10_000) == nil)
    }

    @Test func sinNumeroUsableNoHayCashback() {
        // `nil` y no cero: distingue "no cargó nada" de "cargó cero".
        #expect(CashbackDelGasto(modo: .porcentaje, texto: "").monto(sobre: 10_000) == nil)
        #expect(CashbackDelGasto(modo: .porcentaje, texto: "0").monto(sobre: 10_000) == nil)
        #expect(CashbackDelGasto(modo: .monto, texto: "abc").monto(sobre: 10_000) == nil)
        #expect(CashbackDelGasto(modo: .porcentaje, texto: "20").monto(sobre: 0) == nil)
    }
}
