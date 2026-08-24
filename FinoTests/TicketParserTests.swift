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

    @Test func noConfundeElSubtotalCuandoElOCRSeparaLasColumnas() {
        // Caso reportado: en el papel dice "SUBTOTAL 8.300,50" y
        // "TOTAL 8.000,00", pero Vision devuelve primero los dos rótulos
        // y después los dos importes. El número que quedaba pegado a la
        // palabra TOTAL era el del subtotal.
        let lineas = [
            "DIA ARGENTINA S.A.",
            "SUBTOTAL",
            "TOTAL",
            "8.300,50",
            "8.000,00",
        ]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 8000)
    }

    @Test func noSeVaAlVueltoAlBuscarLaColumnaDeImportes() {
        // Después del total vienen los pagos; el importe del total es el
        // de su columna, no el último número del ticket.
        let lineas = ["KIOSCO", "TOTAL", "8.000,00", "Efectivo 10.000,00", "Vuelto 2.000,00"]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 8000)
    }

    @Test func ignoraSubtotalEscritoSeparado() {
        let lineas = ["KIOSCO", "SUB TOTAL 8.300,50", "TOTAL 8.000,00"]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 8000)
    }

    @Test func ignoraLosTotalesQueNoSonPlata() {
        // "TOTAL ITEMS" y "TOTAL DESCUENTOS" van después del total real y,
        // como se toma el último "TOTAL", le ganaban.
        let lineas = [
            "SUPERMERCADO",
            "TOTAL                  8.000,00",
            "TOTAL ITEMS                   7",
            "TOTAL DESCUENTOS         300,50",
        ]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 8000)
    }

    @Test func sinPalabraTotalUsaElMontoMasGrande() {
        let lineas = ["CAFE MARTINEZ", "CAFE DOBLE 4.200,00", "MEDIALUNA 1.800,00"]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 4200)
    }

    @Test func separaLosProductosDelTicket() {
        let productos = TicketScannerService.parsear(lineas: ticketSupermercado)
            .items.filter { $0.monto > 0 }
        #expect(productos.count == 3)
        #expect(productos.first?.nombre == "Leche Entera 1L")
        #expect(productos.first?.monto == 1850)
        #expect(productos.total == 8300.50)
    }

    @Test func agregaElDescuentoParaCerrarConLoPagado() {
        // Los productos suman 8.300,50 y el ticket cobró 8.000: el
        // detalle lleva un renglón de -300,50 para que cierre.
        let datos = TicketScannerService.parsear(lineas: ticketSupermercado)
        #expect(abs(datos.items.total - 8000) < 0.01)
        // Comparado contra la traducción y no contra el literal: el
        // renglón se arma con String(localized:) y los tests corren en
        // inglés, donde sale "Discounts".
        #expect(datos.items.last?.nombre == String(localized: "Descuentos"))
    }

    @Test func noTomaComoProductoElTotalNiLosPagos() {
        let productos = TicketScannerService.parsear(lineas: ticketSupermercado)
            .items.filter { $0.monto > 0 }
        let nombres = productos.map(\.nombre).joined(separator: " ")
        #expect(!nombres.contains("Total"))
        #expect(!nombres.contains("Subtotal"))
        #expect(!nombres.contains("Descuento"))
        #expect(!nombres.contains("Tarjeta"))
    }

    @Test func separaProductosCuandoElOCRDevuelveLasColumnas() {
        let lineas = [
            "DIA ARGENTINA S.A.",
            "LECHE ENTERA",
            "PAN LACTAL",
            "QUESO CREMOSO",
            "1.850,00",
            "2.300,50",
            "4.150,00",
            "TOTAL 8.300,50",
        ]
        let items = TicketScannerService.parsear(lineas: lineas).items
        #expect(items.count == 3)
        #expect(items.last?.nombre == "Queso Cremoso")
        #expect(items.last?.monto == 4150)
    }

    @Test func separaProductosConPreciosSinCentavos() {
        // Kiosco que imprime los precios enteros. La lectura estricta pide
        // centavos y no encuentra nada; la permisiva sí, y cierra con el
        // total, así que es la que gana.
        let lineas = [
            "KIOSCO EL SOL",
            "ALFAJOR JORGITO        900",
            "COCA COLA 500ML       1200",
            "AGUA MINERAL           800",
            "TOTAL                 2900",
        ]
        let items = TicketScannerService.parsear(lineas: lineas).items
        #expect(items.count == 3)
        #expect(items.total == 2900)
    }

    @Test func noDescartaUnProductoLlamadoTarjeta() {
        // "TARJETA SUBE" es un producto, no la forma de pago: la lectura
        // que lo incluye es la que cuadra con el total.
        let lineas = [
            "KIOSCO",
            "TARJETA SUBE           2.500,00",
            "GOLOSINAS              1.200,00",
            "TOTAL                  3.700,00",
        ]
        let items = TicketScannerService.parsear(lineas: lineas).items
        #expect(items.count == 2)
        #expect(items.contains { $0.nombre == "Tarjeta Sube" })
    }

    @Test func separaProductosConNumerosEnElNombreYColumnasSueltas() {
        // "COCA 2L" tiene un número en el nombre: en la lectura estricta
        // eso cortaba la columna y no se emparejaba nada.
        let lineas = [
            "ALMACEN",
            "COCA 2L",
            "FIDEOS 500G",
            "ARROZ 1KG",
            "3.200,00",
            "1.450,00",
            "2.100,00",
            "TOTAL 6.750,00",
        ]
        let items = TicketScannerService.parsear(lineas: lineas).items
        #expect(items.count == 3)
        #expect(items.first?.nombre == "Coca 2L")
        #expect(items.total == 6750)
    }

    @Test func separaProductosCuandoNombreYPrecioVienenIntercalados() {
        let lineas = [
            "PANADERIA",
            "MEDIALUNAS",
            "2.400,00",
            "PAN FRANCES",
            "1.900,00",
            "TOTAL 4.300,00",
        ]
        let items = TicketScannerService.parsear(lineas: lineas).items
        #expect(items.count == 2)
        #expect(items.total == 4300)
    }

    @Test func noInventaProductosCuandoLaSumaNoCierra() {
        // Un ticket sin detalle legible: aflojar las reglas podría sacar
        // renglones de cualquier lado, pero como no suman el total, no se
        // acepta esa lectura.
        let lineas = ["KIOSCO", "TOTAL", "$ 3.500,00"]
        let items = TicketScannerService.parsear(lineas: lineas).items
        #expect(items.isEmpty)
    }

    @Test func ticketSinDetalleLegibleDevuelveSinItems() {
        let lineas = ["KIOSCO", "TOTAL", "$ 3.500,00"]
        #expect(TicketScannerService.parsear(lineas: lineas).items.isEmpty)
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

    @Test func ignoraElNumeroDeLeyDeTransparenciaFiscal() {
        // Caso real (ticket de KFC): Vision devuelve las columnas como
        // observaciones sueltas, así que el importe no queda pegado a la
        // palabra "TOTAL" y se cae al heurístico del monto más grande.
        // Ahí el 27743 de la ley —que figura en todos los tickets
        // argentinos desde 2024— le ganaba al total real de 16.499,00.
        let lineas = [
            "KFC",
            "DEGASA S.A.",
            "TOTAL",
            "Régimen de Transparencia",
            "Fiscal al Consumidor (L. 27743)",
            "16.499,00",
            "IVA Contenido",
            "2.863,46",
            "PAGOS",
            "MERCADO PAGO",
            "16.499,00",
        ]
        #expect(TicketScannerService.parsear(lineas: lineas).monto == 16499)
    }

    @Test func prefiereImportesConCentavosSobreNumerosSueltos() {
        // Un número grande sin centavos no es plata; el que los tiene, sí.
        let lineas = ["KIOSCO", "REF 998877", "CAFE 4.200,00"]
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
