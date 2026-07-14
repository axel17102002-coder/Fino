import Testing
import Foundation
@testable import Fino

/// Tests de la limpieza de nombres de comercio (Apple Pay / OCR).
struct NombreComercioTests {

    @Test func limpiaPrefijoDeMercadoPago() {
        #expect(NombreComercio.limpiar("MERPAGO*KIOSCO SA 123") == "Kiosco")
    }

    @Test func limpiaPrefijoDePayPal() {
        #expect(NombreComercio.limpiar("PAYPAL *SPOTIFY") == "Spotify")
    }

    @Test func cortaEnSucursal() {
        #expect(NombreComercio.limpiar("CARREFOUR SUCURSAL 45") == "Carrefour")
    }

    @Test func sacaSufijosLegalesYSiglas() {
        #expect(NombreComercio.limpiar("COTO C.I.C.S.A.") == "Coto")
        #expect(NombreComercio.limpiar("DIA ARGENTINA S.A.") == "Dia Argentina")
    }

    @Test func respetaNombresYaProlijos() {
        #expect(NombreComercio.limpiar("Starbucks") == "Starbucks")
        #expect(NombreComercio.limpiar("Café Martínez") == "Café Martínez")
    }

    @Test func siQuedaVacioDevuelveElOriginal() {
        #expect(NombreComercio.limpiar("123 SA") == "123 SA")
        #expect(NombreComercio.limpiar("") == "")
    }
}

/// Tests de la próxima fecha de cierre/vencimiento.
struct ProximaFechaTests {

    private func fecha(_ anio: Int, _ mes: Int, _ dia: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: anio, month: mes, day: dia))!
    }

    @Test func diaFuturoDelMismoMes() {
        #expect(CalculosService.proximaFecha(dia: 20, desde: fecha(2026, 7, 13)) == fecha(2026, 7, 20))
    }

    @Test func diaPasadoVaAlMesSiguiente() {
        #expect(CalculosService.proximaFecha(dia: 5, desde: fecha(2026, 7, 13)) == fecha(2026, 8, 5))
    }

    @Test func hoyCuenta() {
        #expect(CalculosService.proximaFecha(dia: 13, desde: fecha(2026, 7, 13)) == fecha(2026, 7, 13))
    }

    @Test func mesCortoUsaSuUltimoDia() {
        #expect(CalculosService.proximaFecha(dia: 31, desde: fecha(2026, 2, 10)) == fecha(2026, 2, 28))
    }

    @Test func diaInvalidoEsNil() {
        #expect(CalculosService.proximaFecha(dia: 0) == nil)
        #expect(CalculosService.proximaFecha(dia: 32) == nil)
    }
}
