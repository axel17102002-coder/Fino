import Testing
import Foundation
@testable import Fino

/// Tests del parser de tickets (la parte pura, sin OCR).
struct TicketParserTests {

    private let ticketSupermercado = [
        "DIA ARGENTINA S.A.",
        "CUIT: 30-59659829-4",
        "Av. Rivadavia 1234 - CABA",
        "FACTURA B",
        "13/07/2026  19:42",
        "LECHE ENTERA 1L        1.850,00",
        "PAN LACTAL             2.300,50",
        "QUESO CREMOSO x0.3     4.150,00",
        "SUBTOTAL               8.300,50",
        "DESCUENTO                -300,50",
        "TOTAL                  8.000,00",
        "TARJETA DE CREDITO",
        "GRACIAS POR SU COMPRA",
    ]

    @Test func detectaElTotalYNoElSubtotal() {
        let datos = TicketScannerService.parsear(lineas: ticketSupermercado)
        #expect(datos.monto == 8000)
    }

    @Test func detectaElComercioSalteandoLineasFiscales() {
        let datos = TicketScannerService.parsear(lineas: ticketSupermercado)
        #expect(datos.nombre == "Dia Argentina")
    }

    @Test func detectaLaFecha() {
        let datos = TicketScannerService.parsear(lineas: ticketSupermercado)
        let componentes = Calendar.current.dateComponents([.day, .month, .year], from: datos.fecha ?? .distantPast)
        #expect(componentes.day == 13)
        #expect(componentes.month == 7)
        #expect(componentes.year == 2026)
    }

    @Test func totalEnLineaSeparada() {
        // El OCR suele partir las columnas: "TOTAL" y el número quedan
        // en líneas consecutivas.
        let lineas = ["KIOSCO 25", "TOTAL", "$ 3.500,00"]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 3500)
    }

    @Test func sinPalabraTotalUsaElMontoMasGrande() {
        let lineas = ["CAFE MARTINEZ", "CAFE DOBLE 4.200,00", "MEDIALUNA 1.800,00"]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 4200)
    }

    @Test func numerosEnDistintosFormatos() {
        #expect(TicketScannerService.numero(desde: "1.234,56") == 1234.56)
        #expect(TicketScannerService.numero(desde: "1,234.56") == 1234.56)
        #expect(TicketScannerService.numero(desde: "$ 8.000") == 8000)
        #expect(TicketScannerService.numero(desde: "8000") == 8000)
        #expect(TicketScannerService.numero(desde: "123,45") == 123.45)
    }

    @Test func ignoraElCuitComoMonto() {
        let lineas = ["KIOSCO", "CUIT 30-59659829-4", "TOTAL 500,00"]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 500)
    }

    @Test func ignoraElIIBBComoMontoMasGrande() {
        // Caso real: el número de IIBB (646446) es más grande que el
        // total real y, sin la palabra "TOTAL" atada al importe, ganaba
        // el heurístico de "el monto más grande del ticket".
        let lineas = [
            "KFC",
            "CUIT 30-71184094-6",
            "IIBB 902-646446-0",
            "CAFE DOBLE 4.200,00",
            "MEDIALUNA 1.800,00",
        ]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 4200)
    }

    @Test func fechaFueraDeRangoSeIgnora() {
        // Una fecha de vencimiento lejana no es la fecha de compra.
        let lineas = ["KIOSCO", "VTO 01/01/2031", "TOTAL 500,00"]
        #expect(TicketScannerService.parsear(lineas: lineas).fecha == nil)
    }

    @Test func ticketIlegibleDevuelveVacio() {
        let datos = TicketScannerService.parsear(lineas: [])
        #expect(datos.estaVacio)
    }
}
