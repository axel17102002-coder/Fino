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
        #expect(CalculosService.fraccionGastosSobreIngresos([movimiento(.gasto, 500)]) == nil)
        let movimientos = [movimiento(.ingreso, 1000), movimiento(.gasto, 760)]
        #expect(CalculosService.fraccionGastosSobreIngresos(movimientos) == 0.76)
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
        let totales = CalculosService.totalesPorCategoria(movimientos, tipo: .gasto)
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
