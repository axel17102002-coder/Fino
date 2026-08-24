import Testing
import Foundation
@testable import Fino

/// Las inversiones llevadas a dólares, repartidas por clase y por porción.
struct CarteraTests {

    /// 1 peso = 0,001 dólares (o sea, el dólar a 1.000).
    private let tasa = 0.001

    private func accion(_ ticker: String, cantidad: Double, precio: Double) -> Inversion {
        Inversion(nombre: ticker, tipo: .accion, donde: "IBKR", moneda: .usd,
                  cantidad: cantidad, precio: precio)
    }

    private func cripto(_ ticker: String, cantidad: Double, precio: Double) -> Inversion {
        Inversion(nombre: ticker, tipo: .cripto, donde: "Binance", moneda: .usd,
                  cantidad: cantidad, precio: precio)
    }

    private func plazoFijo(_ nombre: String, pesos: Double) -> Inversion {
        Inversion(nombre: nombre, tipo: .plazoFijo, donde: "Galicia", moneda: .ars, monto: pesos)
    }

    @Test func elValorSaleDeCantidadPorPrecio() {
        #expect(accion("AAPL", cantidad: 10, precio: 220).valor == 2_200)
    }

    @Test func elPlazoFijoUsaElCapital() {
        #expect(plazoFijo("Galicia", pesos: 1_500_000).valor == 1_500_000)
    }

    @Test func lasTenenciasEnPesosSeConviertenADolares() {
        // 1.500.000 pesos con el dólar a 1.000 son 1.500 dólares.
        let cartera = Cartera([plazoFijo("Galicia", pesos: 1_500_000)], dolaresPorPeso: tasa)
        #expect(cartera.total == 1_500)
    }

    @Test func elTotalMezclaLasDosMonedas() {
        let cartera = Cartera(
            [accion("AAPL", cantidad: 10, precio: 220), plazoFijo("Galicia", pesos: 1_500_000)],
            dolaresPorPeso: tasa
        )
        #expect(cartera.total == 3_700)
    }

    @Test func sinCotizacionAvisaEnVezDeMentirElTotal() {
        // Sin dólar no se pueden convertir las de pesos. El total muestra
        // solo lo que sí se puede, y la card lo aclara.
        let cartera = Cartera(
            [accion("AAPL", cantidad: 10, precio: 220), plazoFijo("Galicia", pesos: 1_500_000)],
            dolaresPorPeso: nil
        )
        #expect(cartera.total == 2_200)
        #expect(cartera.faltaCotizacion)
    }

    @Test func elRepartoPorClaseVaDeMayorAMenor() {
        let cartera = Cartera([
            accion("AAPL", cantidad: 10, precio: 220),
            cripto("BTC", cantidad: 0.01, precio: 60_000),
        ], dolaresPorPeso: tasa)
        let clases = cartera.porClase
        #expect(clases.first?.tipo == .accion)
        #expect(clases.first?.dolares == 2_200)
        #expect(clases.last?.tipo == .cripto)
        #expect(clases.last?.dolares == 600)
        // Las proporciones suman uno.
        #expect(abs(clases.reduce(0) { $0 + $1.proporcion } - 1) < 0.0001)
    }

    @Test func conMuchasTenenciasElRestoVaAOtras() {
        // Nueve tenencias: seis con nombre propio y las otras tres juntas.
        let muchas = (1...9).map { accion("T\($0)", cantidad: 1, precio: Double(10 - $0) * 100) }
        let segmentos = Cartera(muchas, dolaresPorPeso: tasa).segmentos
        #expect(segmentos.count == 7)
        #expect(segmentos.first?.nombre == "T1")
        // Contra la traducción y no el literal: los tests corren en
        // inglés, donde el renglón dice "Others".
        #expect(segmentos.last?.nombre == String(localized: "Otras"))
        // "Otras" junta las tres más chicas: 300 + 200 + 100.
        #expect(segmentos.last?.monto == 600)
    }

    @Test func conPocasTenenciasNoApareceOtras() {
        let pocas = (1...4).map { accion("T\($0)", cantidad: 1, precio: Double($0) * 100) }
        let segmentos = Cartera(pocas, dolaresPorPeso: tasa).segmentos
        #expect(segmentos.count == 4)
        #expect(!segmentos.contains { $0.nombre == String(localized: "Otras") })
    }

    @Test func avisaLosPlazosFijosQueVencenEnLaSemana() {
        let pronto = plazoFijo("Galicia", pesos: 1_000_000)
        pronto.vencimiento = Calendar.current.date(byAdding: .day, value: 3, to: .now)
        let lejos = plazoFijo("Nación", pesos: 1_000_000)
        lejos.vencimiento = Calendar.current.date(byAdding: .day, value: 40, to: .now)

        let cartera = Cartera([pronto, lejos], dolaresPorPeso: tasa)
        #expect(cartera.porVencer.count == 1)
        #expect(cartera.porVencer.first?.nombre == "Galicia")
    }
}

/// El backup se lleva las inversiones.
struct BackupDeInversionesTests {

    @Test func elBackupViejoSeLeeSinInversiones() throws {
        // Los backups anteriores no traen la clave: tienen que seguir
        // restaurando en vez de fallar al decodificar.
        let json = """
        {"version":2,"fecha":"2026-08-01T00:00:00Z","cuentas":[],"movimientos":[],
         "presupuestos":[],"objetivos":[],"categoriasPersonalizadas":[]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupFino.self, from: Data(json.utf8))
        #expect(backup.inversiones == nil)
    }

    @Test func unaTenenciaSobreviveElViajeDeIdaYVuelta() throws {
        let original = InversionBackup(
            id: UUID(), nombre: "AAPL", tipoRaw: TipoInversion.accion.rawValue,
            donde: "IBKR", monedaRaw: Moneda.usd.rawValue,
            cantidad: 10, precio: 220, monto: nil,
            tasaAnual: nil, vencimiento: nil, orden: 0
        )
        let data = try JSONEncoder().encode(original)
        let vuelta = try JSONDecoder().decode(InversionBackup.self, from: data)
        #expect(vuelta.nombre == "AAPL")
        #expect(vuelta.cantidad == 10)
        #expect(vuelta.precio == 220)
    }
}
