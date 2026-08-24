import Testing
import Foundation
import SwiftData
@testable import Fino

/// Tests de la lógica financiera pura. Van en serie porque varios
/// configuran el día de inicio del mes financiero en UserDefaults.
@Suite(.serialized)
@MainActor
struct CalculosServiceTests {

    // MARK: - Helpers

    private func fecha(_ anio: Int, _ mes: Int, _ dia: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: anio, month: mes, day: dia))!
    }

    private func movimiento(
        _ tipo: TipoMovimiento,
        _ monto: Double,
        fecha: Date = .now,
        categoria: String = CategoriaGasto.comida.rawValue,
        cuotas: Int = 1
    ) -> Movimiento {
        Movimiento(
            tipo: tipo, nombre: "Test", categoriaRaw: categoria,
            monto: monto, fecha: fecha, cuotas: cuotas
        )
    }

    /// Ejecuta el bloque con un día de inicio de mes configurado y
    /// después restaura el valor previo.
    private func conDiaInicio(_ dia: Int, _ cuerpo: () -> Void) {
        let clave = Preferencias.claveDiaInicioMes
        let previo = UserDefaults.standard.integer(forKey: clave)
        UserDefaults.standard.set(dia, forKey: clave)
        cuerpo()
        UserDefaults.standard.set(previo, forKey: clave)
    }

    // MARK: - Totales y balance

    @Test func totalSumaSoloElTipoPedido() {
        let movimientos = [
            movimiento(.gasto, 100), movimiento(.gasto, 50),
            movimiento(.ingreso, 700), movimiento(.cashback, 10),
        ]
        #expect(CalculosService.total(movimientos, tipo: .gasto) == 150)
        #expect(CalculosService.total(movimientos, tipo: .ingreso) == 700)
        #expect(CalculosService.total(movimientos, tipo: .cashback) == 10)
    }

    @Test func balanceEsIngresosMenosGastosMasCashback() {
        let movimientos = [
            movimiento(.ingreso, 1000), movimiento(.gasto, 400), movimiento(.cashback, 25),
        ]
        #expect(CalculosService.balance(movimientos) == 625)
    }

    @Test func fraccionGastosSobreIngresos() {
        #expect(CalculosService.fraccionGastosSobreIngresos([movimiento(.gasto, 500)].comoAportes) == nil)
        let movimientos = [movimiento(.ingreso, 1000), movimiento(.gasto, 760)]
        #expect(CalculosService.fraccionGastosSobreIngresos(movimientos.comoAportes) == 0.76)
    }

    // MARK: - Mes financiero

    @Test func inicioPeriodoConMesCalendario() {
        conDiaInicio(1) {
            #expect(CalculosService.inicioPeriodo(conteniendo: fecha(2026, 7, 20)) == fecha(2026, 7, 1))
        }
    }

    @Test func inicioPeriodoConDiaConfigurado() {
        conDiaInicio(10) {
            // Después del día 10, el período arrancó este mes.
            #expect(CalculosService.inicioPeriodo(conteniendo: fecha(2026, 7, 15)) == fecha(2026, 7, 10))
            // Antes del día 10, el período arrancó el mes pasado.
            #expect(CalculosService.inicioPeriodo(conteniendo: fecha(2026, 7, 5)) == fecha(2026, 6, 10))
        }
    }

    @Test func inicioPeriodoEnMesQueNoLlegaAlDia() {
        conDiaInicio(31) {
            // Febrero de 2026 tiene 28 días: el período arranca el 28.
            #expect(CalculosService.inicioPeriodo(conteniendo: fecha(2026, 2, 28)) == fecha(2026, 2, 28))
        }
    }

    @Test func delMesRespetaElPeriodoFinanciero() {
        conDiaInicio(10) {
            let fuera = movimiento(.gasto, 100, fecha: fecha(2026, 7, 9))
            let dentro = movimiento(.gasto, 200, fecha: fecha(2026, 7, 10))
            let delMes = CalculosService.delMes([fuera, dentro], mes: fecha(2026, 7, 15))
            #expect(delMes.count == 1)
            #expect(delMes.first?.monto == 200)
        }
    }

    // MARK: - Variación y categorías

    @Test func variacionMensualContraElMesAnterior() {
        conDiaInicio(1) {
            let movimientos = [
                movimiento(.gasto, 100, fecha: fecha(2026, 6, 15)),
                movimiento(.gasto, 150, fecha: fecha(2026, 7, 15)),
            ]
            let variacion = CalculosService.variacionMensual(
                movimientos, tipo: .gasto, mes: fecha(2026, 7, 15)
            )
            #expect(variacion == 0.5)
        }
    }

    @Test func variacionMensualSinMesAnteriorEsNil() {
        conDiaInicio(1) {
            let movimientos = [movimiento(.gasto, 150, fecha: fecha(2026, 7, 15))]
            #expect(CalculosService.variacionMensual(movimientos, tipo: .gasto, mes: fecha(2026, 7, 15)) == nil)
        }
    }

    @Test func totalesPorCategoriaAgrupaYOrdenaDescendente() {
        let movimientos = [
            movimiento(.gasto, 100, categoria: CategoriaGasto.comida.rawValue),
            movimiento(.gasto, 40, categoria: CategoriaGasto.comida.rawValue),
            movimiento(.gasto, 500, categoria: CategoriaGasto.viajes.rawValue),
        ]
        let totales = CalculosService.totalesPorCategoria(movimientos.comoAportes, tipo: .gasto)
        #expect(totales.count == 2)
        #expect(totales.first?.categoria.rawValue == CategoriaGasto.viajes.rawValue)
        #expect(totales.first?.total == 500)
        #expect(totales.last?.total == 140)
    }

    @Test func gastadoEnUnaCategoriaIgnoraLasDemas() {
        conDiaInicio(1) {
            let movimientos = [
                movimiento(.gasto, 100, fecha: fecha(2026, 7, 5), categoria: CategoriaGasto.comida.rawValue),
                movimiento(.gasto, 60, fecha: fecha(2026, 7, 6), categoria: CategoriaGasto.viajes.rawValue),
                movimiento(.ingreso, 999, fecha: fecha(2026, 7, 7), categoria: CategoriaIngreso.sueldo.rawValue),
            ]
            #expect(CalculosService.gastado(en: .comida, movimientos: movimientos, mes: fecha(2026, 7, 15)) == 100)
        }
    }

    // MARK: - Cuotas

    @Test func cuotasDeUnaCompra() {
        let hace2Meses = Calendar.current.date(byAdding: .month, value: -2, to: .now)!
        let compra = movimiento(.gasto, 600, fecha: hace2Meses, cuotas: 6)
        #expect(compra.montoCuota == 100)
        #expect(compra.cuotaActual() == 3)
        #expect(compra.cuotasRestantes() == 3)
        #expect(compra.montoPendiente() == 300)
    }

    // MARK: - Cuentas

    @Test func saldoDeCuentaSumaMovimientosAlInicial() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let contenedor = try ModelContainer(for: Cuenta.self, Movimiento.self, configurations: config)
        let contexto = contenedor.mainContext

        let cuenta = Cuenta(nombre: "Banco", tipo: .cuentaBancaria, saldoInicial: 1000)
        contexto.insert(cuenta)
        contexto.insert(Movimiento(
            tipo: .ingreso, nombre: "Sueldo",
            categoriaRaw: CategoriaIngreso.sueldo.rawValue, monto: 500, cuenta: cuenta
        ))
        contexto.insert(Movimiento(
            tipo: .gasto, nombre: "Súper",
            categoriaRaw: CategoriaGasto.supermercado.rawValue, monto: 200, cuenta: cuenta
        ))
        try contexto.save()

        #expect(CalculosService.saldo(de: cuenta) == 1300)
    }

    // MARK: - Series mensuales

    @Test func seriesMensualesAcumulaDesdeAntesDeLaVentanaVisible() {
        conDiaInicio(1) {
            let ahora = Date.now.inicioDeMes
            let movimientos = [
                // Fuera de la ventana de 3 meses: debe sumarse igual al arranque.
                movimiento(.ingreso, 1000, fecha: ahora.agregandoMeses(-10)),
                movimiento(.ingreso, 1000, fecha: ahora.agregandoMeses(-2)),
                movimiento(.gasto, 400, fecha: ahora.agregandoMeses(-2)),
                movimiento(.ingreso, 500, fecha: ahora.agregandoMeses(-1)),
                movimiento(.gasto, 100, fecha: ahora.agregandoMeses(-1)),
                movimiento(.ingreso, 200, fecha: ahora),
                movimiento(.gasto, 50, fecha: ahora),
            ]
            let series = CalculosService.seriesMensuales(movimientos, meses: 3)
            #expect(series.map(\.acumulado) == [1600, 2000, 2150])
        }
    }

    // MARK: - Otros indicadores

    @Test func diaSemanaConMasGasto() {
        // El 6 de julio de 2026 fue lunes (weekday 2 en Calendar).
        let movimientos = [
            movimiento(.gasto, 1000, fecha: fecha(2026, 7, 6)),
            movimiento(.gasto, 10, fecha: fecha(2026, 7, 7)),
        ]
        #expect(CalculosService.diaSemanaConMasGasto(movimientos) == 2)
    }
}

/// Resumen cerrado de una tarjeta: lo que hay que pagar entre el cierre y
/// el vencimiento. Antes la tarjeta mostraba siempre el ciclo en curso, y
/// al pasar el cierre se ponía en cero justo cuando más importaba.
@Suite(.serialized)
struct ResumenDeTarjetaTests {

    /// Tarjeta que cierra el 25 y vence el 10, con la fecha simulada un
    /// día después del cierre.
    private func tarjetaYFecha() -> (Cuenta, Date) {
        let tarjeta = Cuenta(
            nombre: "Visa",
            tipo: .tarjetaCredito,
            diaCierre: 25,
            diaVencimiento: 10
        )
        var componentes = DateComponents()
        componentes.year = 2026
        componentes.month = 7
        componentes.day = 26
        let hoy = Calendar.current.date(from: componentes)!
        return (tarjeta, hoy)
    }

    private func gasto(_ monto: Double, dia: Int, mes: Int, en tarjeta: Cuenta) -> Movimiento {
        var componentes = DateComponents()
        componentes.year = 2026
        componentes.month = mes
        componentes.day = dia
        let movimiento = Movimiento(
            tipo: .gasto,
            nombre: "Compra",
            categoriaRaw: CategoriaGasto.otros.rawValue,
            monto: monto,
            fecha: Calendar.current.date(from: componentes)!
        )
        movimiento.cuenta = tarjeta
        return movimiento
    }

    @Test func despuesDelCierreMuestraLoQueHayQuePagar() {
        let (tarjeta, hoy) = tarjetaYFecha()
        // Dos compras del resumen que cerró el 25 de julio y una del
        // ciclo nuevo, que todavía no se paga.
        tarjeta.movimientos = [
            gasto(10_000, dia: 30, mes: 6, en: tarjeta),
            gasto(5_000, dia: 20, mes: 7, en: tarjeta),
            gasto(3_000, dia: 26, mes: 7, en: tarjeta),
        ]

        #expect(CalculosService.resumenCerrado(de: tarjeta, al: hoy) == 15_000)
        // El ciclo nuevo arrancó: solo la compra del 26.
        #expect(CalculosService.consumoActual(de: tarjeta, al: hoy) == 3_000)
        // Y la tarjeta muestra lo que hay que pagar, no el ciclo nuevo.
        #expect(CalculosService.importeAMostrar(de: tarjeta, al: hoy) == 15_000)
    }

    @Test func alMarcarlaPagadaPasaAMostrarElCicloNuevo() {
        let (tarjeta, hoy) = tarjetaYFecha()
        tarjeta.movimientos = [
            gasto(5_000, dia: 20, mes: 7, en: tarjeta),
            gasto(3_000, dia: 26, mes: 7, en: tarjeta),
        ]
        #expect(tarjeta.tieneResumenSinPagar(al: hoy))

        tarjeta.marcarResumenPagado(al: hoy)

        #expect(!tarjeta.tieneResumenSinPagar(al: hoy))
        #expect(CalculosService.importeAMostrar(de: tarjeta, al: hoy) == 3_000)
    }

    @Test func sePuedeDeshacerElPagada() {
        let (tarjeta, hoy) = tarjetaYFecha()
        tarjeta.movimientos = [
            gasto(5_000, dia: 20, mes: 7, en: tarjeta),
            gasto(3_000, dia: 26, mes: 7, en: tarjeta),
        ]
        tarjeta.marcarResumenPagado(al: hoy)
        #expect(tarjeta.resumenMarcadoPagado(al: hoy))

        tarjeta.desmarcarResumenPagado()

        #expect(!tarjeta.resumenMarcadoPagado(al: hoy))
        #expect(CalculosService.hayResumenAPagar(de: tarjeta, al: hoy))
        #expect(CalculosService.importeAMostrar(de: tarjeta, al: hoy) == 5_000)
    }

    @Test func tarjetaSinConsumosNoTieneNadaQuePagar() {
        // Una tarjeta recién creada nunca marcó un resumen como pagado,
        // pero tampoco debe cero: mostrarle "A pagar $ 0" no tiene sentido.
        let (tarjeta, hoy) = tarjetaYFecha()
        #expect(!CalculosService.hayResumenAPagar(de: tarjeta, al: hoy))
        #expect(CalculosService.importeAMostrar(de: tarjeta, al: hoy) == 0)
    }

    @Test func elCierreSiguienteVuelveADejarlaPendiente() {
        let (tarjeta, hoy) = tarjetaYFecha()
        tarjeta.marcarResumenPagado(al: hoy)
        #expect(!tarjeta.tieneResumenSinPagar(al: hoy))

        // Un mes después ya cerró otro resumen: vuelve a estar pendiente
        // sin que haya que resetear nada a mano.
        let mesQueViene = Calendar.current.date(byAdding: .month, value: 1, to: hoy)!
        #expect(tarjeta.tieneResumenSinPagar(al: mesQueViene))
    }
}

/// Cómo pesan las compras en cuotas en los totales de cada mes.
struct CuotasEnLosTotalesTests {

    private func fecha(_ dia: Int, _ mes: Int, _ anio: Int = 2026) -> Date {
        var c = DateComponents(); c.year = anio; c.month = mes; c.day = dia
        return Calendar.current.date(from: c)!
    }

    private func compra(_ monto: Double, cuotas: Int, dia: Int, mes: Int) -> Movimiento {
        let m = Movimiento(
            tipo: .gasto,
            nombre: "TV",
            categoriaRaw: CategoriaGasto.otros.rawValue,
            monto: monto,
            fecha: fecha(dia, mes)
        )
        m.cuotas = cuotas
        return m
    }

    @Test func laCompraFinanciadaAportaUnaCuotaPorMes() {
        // 120.000 en 12 cuotas compradas en marzo: 10.000 por mes, no
        // 120.000 en marzo y nada después.
        let tv = compra(120_000, cuotas: 12, dia: 10, mes: 3)
        for mes in 3...12 {
            let total = CalculosService.total(
                CalculosService.delMes([tv], mes: fecha(15, mes)), tipo: .gasto
            )
            #expect(total == 10_000, "mes \(mes)")
        }
    }

    @Test func despuesDeLaUltimaCuotaNoAportaMas() {
        // 3 cuotas desde marzo: marzo, abril y mayo. En junio, cero.
        let tv = compra(30_000, cuotas: 3, dia: 10, mes: 3)
        #expect(CalculosService.total(CalculosService.delMes([tv], mes: fecha(15, 5)), tipo: .gasto) == 10_000)
        #expect(CalculosService.delMes([tv], mes: fecha(15, 6)).isEmpty)
    }

    @Test func antesDeLaCompraNoAporta() {
        let tv = compra(30_000, cuotas: 3, dia: 10, mes: 3)
        #expect(CalculosService.delMes([tv], mes: fecha(15, 2)).isEmpty)
    }

    @Test func elPagoUnicoSigueCayendoEnteroEnSuMes() {
        let cafe = compra(8_000, cuotas: 1, dia: 10, mes: 3)
        #expect(CalculosService.total(CalculosService.delMes([cafe], mes: fecha(15, 3)), tipo: .gasto) == 8_000)
        #expect(CalculosService.delMes([cafe], mes: fecha(15, 4)).isEmpty)
    }

    @Test func laCuotaDeUnGastoCompartidoEsSoloTuParte() {
        // 120.000 en 12 cuotas a medias: te tocan 5.000 por mes.
        let tv = compra(120_000, cuotas: 12, dia: 10, mes: 3)
        tv.montoAjeno = 60_000
        let total = CalculosService.total(
            CalculosService.delMes([tv], mes: fecha(15, 5)), tipo: .gasto
        )
        #expect(total == 5_000)
    }

    @Test func elPresupuestoCuentaLaCuotaYNoElTotal() {
        let tv = compra(120_000, cuotas: 12, dia: 10, mes: 3)
        let gastado = CalculosService.gastado(
            en: .otros, movimientos: [tv], mes: fecha(15, 6)
        )
        #expect(gastado == 10_000)
    }

    @Test func elMayorGastoDelMesComparaCuotas() {
        // La TV en 12 cuotas pesa 10.000 este mes; el sillón de 30.000 al
        // contado pesa más aunque su total sea menor.
        let tv = compra(120_000, cuotas: 12, dia: 10, mes: 3)
        let sillon = compra(30_000, cuotas: 1, dia: 12, mes: 5)
        sillon.nombre = "Sillón"
        let mayor = CalculosService.mayorGasto([tv, sillon], mes: fecha(15, 5))
        #expect(mayor?.nombre == "Sillón")
    }
}

/// En qué mes pesa una compra con tarjeta, según el cierre del resumen.
struct CierreDeTarjetaEnLosTotalesTests {

    private func fecha(_ dia: Int, _ mes: Int, _ anio: Int = 2026) -> Date {
        var c = DateComponents(); c.year = anio; c.month = mes; c.day = dia
        return Calendar.current.date(from: c)!
    }

    /// Tarjeta que cierra el 25.
    private func tarjeta() -> Cuenta {
        Cuenta(nombre: "Visa", tipo: .tarjetaCredito, diaCierre: 25, diaVencimiento: 10)
    }

    private func compra(_ monto: Double, dia: Int, mes: Int, cuotas: Int = 1, en cuenta: Cuenta?) -> Movimiento {
        let m = Movimiento(
            tipo: .gasto,
            nombre: "Compra",
            categoriaRaw: CategoriaGasto.otros.rawValue,
            monto: monto,
            fecha: fecha(dia, mes)
        )
        m.cuotas = cuotas
        m.cuenta = cuenta
        return m
    }

    private func gastoDe(_ movimientos: [Movimiento], mes: Int) -> Double {
        CalculosService.total(
            CalculosService.delMes(movimientos, mes: fecha(15, mes)), tipo: .gasto
        )
    }

    @Test func loCompradoDespuesDelCierrePesaElMesQueViene() {
        // Compra del 28 de julio con cierre el 25: entra en el resumen que
        // cierra el 25 de agosto, así que pesa en agosto.
        let compra = compra(10_000, dia: 28, mes: 7, en: tarjeta())
        #expect(gastoDe([compra], mes: 7) == 0)
        #expect(gastoDe([compra], mes: 8) == 10_000)
    }

    @Test func loCompradoAntesDelCierrePesaEsteMes() {
        let compra = compra(10_000, dia: 10, mes: 7, en: tarjeta())
        #expect(gastoDe([compra], mes: 7) == 10_000)
        #expect(gastoDe([compra], mes: 8) == 0)
    }

    @Test func comprarElDiaDelCierreEntraEnEseResumen() {
        // El límite: el 25 todavía es de este resumen, el 26 ya no.
        let elDia = compra(10_000, dia: 25, mes: 7, en: tarjeta())
        let alDiaSiguiente = compra(10_000, dia: 26, mes: 7, en: tarjeta())
        #expect(gastoDe([elDia], mes: 7) == 10_000)
        #expect(gastoDe([alDiaSiguiente], mes: 7) == 0)
        #expect(gastoDe([alDiaSiguiente], mes: 8) == 10_000)
    }

    @Test func lasCuotasArrancanEnElResumenQueEntroLaCompra() {
        // Comprada el 28 de julio en 3 cuotas: agosto, septiembre y
        // octubre. Julio queda en cero.
        let tv = compra(30_000, dia: 28, mes: 7, cuotas: 3, en: tarjeta())
        #expect(gastoDe([tv], mes: 7) == 0)
        #expect(gastoDe([tv], mes: 8) == 10_000)
        #expect(gastoDe([tv], mes: 9) == 10_000)
        #expect(gastoDe([tv], mes: 10) == 10_000)
        #expect(gastoDe([tv], mes: 11) == 0)
    }

    @Test func sinTarjetaLaFechaEsLaDeLaCompra() {
        // Efectivo o débito: el cierre no aplica y el 28 pesa en julio.
        let efectivo = Cuenta(nombre: "Efectivo", tipo: .efectivo)
        let compra = compra(10_000, dia: 28, mes: 7, en: efectivo)
        #expect(gastoDe([compra], mes: 7) == 10_000)
    }

    @Test func tarjetaSinDiaDeCierreUsaLaFechaDeLaCompra() {
        // Si nunca configuraste el cierre no hay resumen que calcular.
        let sinCierre = Cuenta(nombre: "Visa", tipo: .tarjetaCredito)
        let compra = compra(10_000, dia: 28, mes: 7, en: sinCierre)
        #expect(gastoDe([compra], mes: 7) == 10_000)
    }
}

/// Lo que muestra la tarjeta cuando hay compras en cuotas.
struct ConsumoDeTarjetaEnCuotasTests {

    private func fecha(_ dia: Int, _ mes: Int, _ anio: Int = 2026) -> Date {
        var c = DateComponents(); c.year = anio; c.month = mes; c.day = dia
        return Calendar.current.date(from: c)!
    }

    private func tarjetaCon(_ movimientos: [Movimiento]) -> Cuenta {
        let tarjeta = Cuenta(nombre: "Visa", tipo: .tarjetaCredito, diaCierre: 25, diaVencimiento: 10)
        for m in movimientos { m.cuenta = tarjeta }
        tarjeta.movimientos = movimientos
        return tarjeta
    }

    private func compra(_ monto: Double, dia: Int, mes: Int, cuotas: Int = 1) -> Movimiento {
        let m = Movimiento(
            tipo: .gasto,
            nombre: "TV",
            categoriaRaw: CategoriaGasto.otros.rawValue,
            monto: monto,
            fecha: fecha(dia, mes)
        )
        m.cuotas = cuotas
        return m
    }

    @Test func laTarjetaMuestraLaCuotaYNoElTotal() {
        // 120.000 en 12 cuotas: en el resumen te cobran 10.000, no
        // 120.000 el mismo día de comprarla.
        let tv = compra(120_000, dia: 10, mes: 7, cuotas: 12)
        let tarjeta = tarjetaCon([tv])
        #expect(CalculosService.consumoActual(de: tarjeta, al: fecha(20, 7)) == 10_000)
    }

    @Test func mesesDespuesSigueSiendoUnaCuota() {
        let tv = compra(120_000, dia: 10, mes: 7, cuotas: 12)
        let tarjeta = tarjetaCon([tv])
        #expect(CalculosService.consumoActual(de: tarjeta, al: fecha(20, 10)) == 10_000)
    }

    @Test func terminadoElPlanDejaDeSumar() {
        // 3 cuotas desde julio: en noviembre ya no debe nada.
        let tv = compra(30_000, dia: 10, mes: 7, cuotas: 3)
        let tarjeta = tarjetaCon([tv])
        #expect(CalculosService.consumoActual(de: tarjeta, al: fecha(20, 11)) == 0)
    }

    @Test func lasCuotasSeSumanALasComprasDelCiclo() {
        let tv = compra(120_000, dia: 10, mes: 7, cuotas: 12)
        let cafe = compra(5_000, dia: 20, mes: 7)
        let tarjeta = tarjetaCon([tv, cafe])
        #expect(CalculosService.consumoActual(de: tarjeta, al: fecha(21, 7)) == 15_000)
    }

    @Test func elGastoDelMesDeLaCuentaTambienCuentaLaCuota() {
        let tv = compra(120_000, dia: 10, mes: 7, cuotas: 12)
        let tarjeta = tarjetaCon([tv])
        #expect(CalculosService.gastoDelMes(de: tarjeta, mes: fecha(15, 7)) == 10_000)
        #expect(CalculosService.gastoDelMes(de: tarjeta, mes: fecha(15, 8)) == 10_000)
    }
}

extension ConsumoDeTarjetaEnCuotasTests {

    @Test func elResumenCerradoTampocoCobraDeMas() {
        // El mismo recorte de `cuotaActual` hacía que el resumen cerrado
        // siguiera trayendo la última cuota de un plan ya terminado.
        let tv = compra(30_000, dia: 10, mes: 7, cuotas: 3)
        let tarjeta = tarjetaCon([tv])
        #expect(CalculosService.resumenCerrado(de: tarjeta, al: fecha(20, 12)) == 0)
    }

    @Test func laCuotaQueSeMuestraSigueAcotada() {
        // Para el rótulo "Cuota 3/3" el recorte sí es lo correcto.
        let tv = compra(30_000, dia: 10, mes: 7, cuotas: 3)
        #expect(tv.cuotaActual(al: fecha(20, 11)) == 3)
        #expect(tv.numeroDeCuota(al: fecha(20, 11)) == 5)
    }
}

/// Los gastos de una tarjeta agrupados por resumen.
struct ResumenesDeTarjetaTests {

    private func fecha(_ dia: Int, _ mes: Int, _ anio: Int = 2026) -> Date {
        var c = DateComponents(); c.year = anio; c.month = mes; c.day = dia
        return Calendar.current.date(from: c)!
    }

    private func tarjetaCon(_ movimientos: [Movimiento]) -> Cuenta {
        let tarjeta = Cuenta(nombre: "Visa", tipo: .tarjetaCredito, diaCierre: 25, diaVencimiento: 10)
        for m in movimientos { m.cuenta = tarjeta }
        tarjeta.movimientos = movimientos
        return tarjeta
    }

    private func compra(_ nombre: String, _ monto: Double, dia: Int, mes: Int, cuotas: Int = 1) -> Movimiento {
        let m = Movimiento(
            tipo: .gasto, nombre: nombre,
            categoriaRaw: CategoriaGasto.otros.rawValue,
            monto: monto, fecha: fecha(dia, mes)
        )
        m.cuotas = cuotas
        return m
    }

    @Test func loCompradoDespuesDelCierreVaAlResumenSiguiente() {
        // Cierre el 25: el 10 entra en el de julio, el 28 en el de agosto.
        let tarjeta = tarjetaCon([
            compra("Nafta", 20_000, dia: 10, mes: 7),
            compra("Cena", 30_000, dia: 28, mes: 7),
        ])
        let resumenes = CalculosService.resumenesDeTarjeta(tarjeta)
        #expect(resumenes.count == 2)
        // Ordenados del más nuevo al más viejo.
        #expect(resumenes[0].total == 30_000)
        #expect(resumenes[1].total == 20_000)
    }

    @Test func unaCompraEnCuotasApareceEnVariosResumenes() {
        let tarjeta = tarjetaCon([compra("TV", 30_000, dia: 10, mes: 7, cuotas: 3)])
        let resumenes = CalculosService.resumenesDeTarjeta(tarjeta)
        #expect(resumenes.count == 3)
        // En cada uno entra la cuota, no el total.
        #expect(resumenes.allSatisfy { $0.total == 10_000 })
        // Y sabe cuál cuota es: del más nuevo al más viejo, 3, 2 y 1.
        #expect(resumenes.map { $0.renglones.first?.cuota } == [3, 2, 1])
    }

    @Test func lasCuotasViejasSeSumanALasComprasNuevas() {
        let tarjeta = tarjetaCon([
            compra("TV", 30_000, dia: 10, mes: 7, cuotas: 3),
            compra("Nafta", 5_000, dia: 10, mes: 8),
        ])
        let resumenes = CalculosService.resumenesDeTarjeta(tarjeta)
        let agosto = resumenes.first { Calendar.current.component(.month, from: $0.cierre) == 8 }
        #expect(agosto?.total == 15_000)
        #expect(agosto?.renglones.count == 2)
    }

    @Test func sinDiaDeCierreNoHayResumenes() {
        let tarjeta = Cuenta(nombre: "Visa", tipo: .tarjetaCredito)
        let compra = compra("Nafta", 5_000, dia: 10, mes: 7)
        compra.cuenta = tarjeta
        tarjeta.movimientos = [compra]
        #expect(CalculosService.resumenesDeTarjeta(tarjeta).isEmpty)
    }
}
