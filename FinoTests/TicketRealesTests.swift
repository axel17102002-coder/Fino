import Testing
import Foundation
@testable import Fino

/// Tickets reales, con el texto tal cual lo devuelve Vision.
///
/// Estos casos salieron de fotos de verdad y traen cosas que no se le
/// ocurren a uno escribiendo un caso a mano: la palabra "TOTAL" leída
/// como "IOTAL", un "$" solo arriba de la columna de importes, el precio
/// en un renglón aparte como "1 x 1659,00", y los descuentos metidos en
/// el medio de la columna.
struct TicketRealesTests {

    // MARK: Carrefour La Plata II — 8 productos, con descuentos

    private let carrefourConDescuentos = [
        "18:38",
        "< Detalle de ticket",
        "Carrefour",
        "144 LA PLATA II",
        "CALLE 12 N 1200",
        "INC SA - CUIT Nro:30-68731043-4",
        "IBCM 30-68731043-4",
        "Inicio actividad comercial: 01/09/1989",
        "ORIENTACION AL CONSUMIDOR",
        "CELU 11-6910-5187 / 0-800-666-1518",
        "IVA RESPONSABLE INSCRIPTO",
        "FACTURA B (Cod. 006",
        "1 CONSUMIDOR FINAI",
        "P.V. Nro.:16827",
        "Fecha 19/07/26",
        "Caja 0007",
        "Nro T. 00523918",
        "Hora 00:52:17",
        "Cajero/a: 9-OSCAR RA",
        "Almacen",
        "CARAMELOS DE CHOCOLATE BUTTER TOFFES X 8",
        "1 x 1659,00",
        "(21.00%)",
        "7790580152109",
        "PALITOS RUEDITAS PEP BOLSA X 74 GRS",
        "1 x 2149,00",
        "(21.00%)",
        "7790310984314",
        "ALFAJOR LECHE BON O BON X 40 GRS",
        "1 x 1279,00",
        "(21.00%)",
        "7790040613706",
        "GOMITAS TUBITOS MOGUL EXTREME FRUTILLA X",
        "2 x 750,00",
        "(21.00%)",
        "2do50%-MOGUL-GOLOS",
        "7790580146375",
        "ALFAJOR TRIPLE PEPITOS X 57 GRS",
        "2 × 2150,00",
        "(21.00%)",
        "2d050%-PEPITOS-ALF",
        "77915481",
        "TABLETA CHOCOLATE BLANCO MILKA OREO X 20",
        "2 x 1689,00",
        "(21.00%)",
        "2do70%-MILKA-GOLOS",
        "7622210795908",
        "PAPAS FRITAS JAMON SERRANO LAYS X 77 GRS",
        "1 x 3849,00",
        "(21.00%)",
        "7790310985434",
        "Bebidas",
        "GASEOSA LIMA LIMON REGULAR 7 UP N PET X",
        "1 x 3950,00",
        "(21.00%)-[16.94%]",
        "7791813444411",
        "1659.00",
        "2149.00",
        "1279.00",
        "1500.00",
        "-375.00",
        "300.0",
        "1075.0",
        "378.0",
        "1182.3",
        "3849.00",
        "3950.00",
        "SUBTOTAL SIN DESCUENTOS",
        "22064,00",
        "DESCUENTOS",
        "2do50%-MOGUL-GOLOS2",
        "2do50%-PEPITOS-ALFAJ2",
        "2do70%-MILKA-GOLOS2",
        "AHORRO",
        "TOTAL",
        "$",
        "-375.00",
        "-1075.00",
        "-1182.30",
        "$ 2632.30",
        "19431.70",
        "REG. TRANSPARENCIA FISCAL AL CONSUMIDOR LEY 27743",
        "IVA Contenido",
        "Otros impuestos nacionales indirectos",
        "3356.03",
        "0.00",
        "LOS IMPUESTOS INFORMADOS SON A NIVEL NACIONAL",
        "Pago MERCADOPAGO",
        "Suma de sus pagos",
        "$",
        "19431,70",
        "19431.70",
        "3665 0144 007 009 Art: 0011 190726 0052 AC-00",
        "FACTURA ELECTRONICA",
        "CAE 86294525060528",
        "Vto: 29/07/26",
    ]

    @Test func carrefourTomaElTotalYNoElSubtotal() {
        // El importe del total está al final de una columna que arranca
        // con los descuentos en negativo, y arriba hay un "$" suelto.
        #expect(TicketScannerService.parsear(lineas: carrefourConDescuentos).monto == 19431.70)
    }

    @Test func carrefourSeparaLosOchoProductos() {
        let datos = TicketScannerService.parsear(lineas: carrefourConDescuentos)
        let productos = datos.items.filter { $0.monto > 0 }
        #expect(productos.count == 8)
        // Los productos suman el subtotal sin descuentos que trae impreso.
        #expect(productos.total == 22064)
        // Cantidad × precio unitario: dos a 750 son 1500.
        #expect(productos.contains { $0.nombre.hasPrefix("Gomitas Tubitos Mogul") && $0.monto == 1500 })
    }

    @Test func carrefourCierraElDetalleConElDescuento() {
        // Con las promociones aplicadas, el detalle tiene que dar lo mismo
        // que se pagó: 22.064 de productos menos 2.632,30 de descuentos.
        let datos = TicketScannerService.parsear(lineas: carrefourConDescuentos)
        #expect(abs((datos.items.last?.monto ?? 0) + 2632.30) < 0.01)
        #expect(abs(datos.items.total - (datos.monto ?? 0)) < 0.01)
    }

    @Test func usaElNombreDelProductoYNoElRubro() {
        // El nombre sale de la línea de arriba del "1 x 1659,00". Como casi
        // todos traen el gramaje ("... X 8", "... X 74 GRS"), saltearlos
        // por tener números dejaba de nombre el rubro de la góndola.
        let productos = TicketScannerService.parsear(lineas: carrefourConDescuentos)
            .items.filter { $0.monto > 0 }
        #expect(productos.first?.nombre == "Caramelos De Chocolate Butter Toffes X 8")
        #expect(productos.last?.nombre == "Gaseosa Lima Limon Regular 7 Up N Pet X")
        let nombres = productos.map(\.nombre)
        #expect(!nombres.contains("Almacen"))
        #expect(!nombres.contains("Bebidas"))
    }

    @Test func tomaElTotalAunqueElOCRSeComaLosSignosMenos() {
        // Caso reportado: en otra foto del mismo ticket el OCR no
        // reconoció los "-" de los descuentos, la columna del total quedó
        // corrida y devolvía 375 —el primer descuento— en vez de
        // 19.431,70. Lo salva que el total figura impreso dos veces.
        let sinSignos = carrefourConDescuentos.map {
            $0.hasPrefix("-") ? String($0.dropFirst()) : $0
        }
        #expect(TicketScannerService.parsear(lineas: sinSignos).monto == 19431.70)
    }

    @Test func carrefourDetectaElComercio() {
        #expect(TicketScannerService.parsear(lineas: carrefourConDescuentos).nombre == "Carrefour")
    }

    // MARK: Carrefour La Plata I — el OCR leyó "IOTAL"

    private let carrefourTotalMalLeido = [
        "18:38 4",
        "< Detalle de ticket",
        "Carrefour",
        "109 LA PLATA I",
        "CALLE 7 Nø 767",
        "INC SA - CUIT Nro:30-68731043-4",
        "IBCM 30-68731043-4",
        "Inicio actividad comercial: 02/02/1986",
        "ORIENTACION AL CONSUMIDOR",
        "AVELLANEDA",
        "0-800-666-1518",
        "IVA RESPONSABLE INSCRIPTO",
        "FACTURA B (Cod.006)",
        "A CONSUMIDOR FINAL",
        "P.V. Nro.:18677",
        "Fecha 29/07/26",
        "Caja 0012",
        "Nro T. 00193416",
        "Hora 21:18:18",
        "Cajero/a: Local109-S",
        "Almacen",
        "QUESO FUNDIDO LIGHT FINLANDIA POTE X 180",
        "1 x 3649,00",
        "(21.00%)",
        "258uni-QUESOS U",
        "7790742321800",
        "Frutas Y Verduras",
        "ARROZ PARA SUSHI",
        "1 x 3049,00",
        "(21.00%)",
        "7798143356032",
        "Platos Preparados",
        "HUMMUS CON ACEITE DE OLIVA CLASSIC X 230",
        "1 x 2990,00",
        "(21.00%)",
        "7791720043936",
        "SUBTOTAL SIN DESCUENIOS",
        "DESCUENTOS",
        "258uni-QUESOS U",
        "AHORRO",
        "IOTAL",
        "$",
        "3649.00",
        "-912.25",
        "3049.00",
        "2990.00",
        "9688,00",
        "-912.25",
        "$912.25",
        "8775.75",
        "REG. TRANSPARENCIA FISCAL AL CONSUMIDOR LEY 27743",
        "IVA Contenido",
        "1523.06",
        "0orot irpsestacionassindi net MACTowAL:",
        "ago MOD",
        "recio Contac",
        "Importe financiado (PFT)",
        "Cantidad de cuotas mensuales",
        "Monto de cuota",
        "TEA",
        "CFT",
        "8775,7",
        "8775,7",
        "$ 8775,75",
        "6.00%",
        "Sistema de amortizacion Frances",
        "Suma de sus pagos",
        "3954 0109 012 033 290726 2118 AC-00",
        "8775.75",
        "CAE 86305990247679",
    ]

    @Test func tomaElTotalAunqueElOCRHayaLeidoIOTAL() {
        // No queda ninguna palabra "TOTAL" utilizable: el rótulo salió
        // "IOTAL". Lo salva que el total está impreso tres veces y el
        // subtotal una sola.
        #expect(TicketScannerService.parsear(lineas: carrefourTotalMalLeido).monto == 8775.75)
    }

    @Test func separaLosProductosAunqueElTotalEsteMalLeido() {
        let datos = TicketScannerService.parsear(lineas: carrefourTotalMalLeido)
        let productos = datos.items.filter { $0.monto > 0 }
        #expect(productos.count == 3)
        #expect(productos.total == 9688)
        // Los rubros ("Almacen", "Frutas Y Verduras", "Platos Preparados")
        // no son productos.
        #expect(productos.map(\.nombre) == [
            "Queso Fundido Light Finlandia Pote X 180",
            "Arroz Para Sushi",
            "Hummus Con Aceite De Oliva Classic X 230",
        ])
        // Y el detalle cierra con lo pagado: 9.688 menos 912,25 de ahorro.
        #expect(abs(datos.items.total - (datos.monto ?? 0)) < 0.01)
    }

    // MARK: KFC — el detalle no es legible, el total sí

    private let kfc = [
        "KFC",
        "DEGASA S.A.",
        "CUIT 30-71184094-6",
        "IIBB 902-646446-0",
        "CALLE 86A # 13-42 PISO 4",
        "AVENIDA 7, 777",
        "Inicio Actividades 19/01/2011",
        "RESPONSABLE INSCRIPTO",
        "CLIENTE: CONSUMIDOR FINAL",
        "FACTURA B",
        "COD. 006",
        "HORA: 13:30:02",
        "FECHA: 19/07/2026",
        "PV 817 N° 00074278",
        "Chk: K110F000644529",
        "CAJERO/A: K110KIOSC03",
        "N° DE TURNO: 29",
        "DETALLE",
        "1 *PAPA MEDIANA LLV",
        "1 *COCA LLV",
        "1 *1 BEB MED LLV",
        "1 Cupon 2 papas me",
        "1 Cafe chico + tos",
        "1 Combo Ruster Med",
        "1 *Cepita Naranja",
        "TOTAL",
        "Régimen de Transparencia",
        "Fiscal al Consumidor (L. 27743)",
        "IVA Contenido",
        "PAGOS",
        "MERCADO PAGO",
        "Nº 86294561658102",
        "CAE",
        "Vto. 2026-07-29",
        "GRACIAS POR TU COMPRA",
        "(21.00) 0.00",
        "(21.00) 0.00",
        "(21.00) 0.00",
        "(21.00) 4.000,00",
        "(21.00) 4.399,00",
        "(21.00) 8.100,00",
        "(21.00) 0.00",
        "16.499,00",
        "2.863,46",
        "16.499,00",
    ]

    @Test func kfcTomaElTotal() {
        #expect(TicketScannerService.parsear(lineas: kfc).monto == 16499)
    }

    // MARK: DIA — cantidad, precio y nombre en renglones sueltos

    private let dia = [
        "BONINO HECTOR_EDGARDO",
        "A CUENTA Y ORDEN DE DIA ARG. SA",
        "CUIT:20-18492319-0",
        "AV",
        "7 423",
        "LA PLATA",
        "IVA RESPONSABLE INSCRIPTO",
        "ING.BRUTOS: 20-18492319-0",
        "FACTÜRA B ORIGINAL (COD",
        "006)",
        "A CONSUMIDOR FINAL CULT:",
        "NUM.00011-00348346 09-07-2026 13:30:4",
        "TDA:05511 CAJA:02 NTrX:055110200065286",
        "Cant./Precio Unit",
        "Descripcion",
        "(%IVA)",
        "[%BI ]",
        "IMPORTE",
        "1,00",
        "2695,00",
        "PAPAS FRITAS LAYS",
        "(21,00)",
        "2695,00",
        "7790310985458",
        "1,00",
        "5280,00",
        "SMIRNOFF CITRIC",
        "(21,00)",
        "5280,00",
        "7791250003011",
        "1,00",
        "4730,00",
        "CERÉAL BOLITAS CHÓCO (21,00)",
        "4730,00",
        "7891000337271",
        "3,00",
        "1690",
        "CHOCOLATÊ OREO BLANC (21,00)",
        "7622210795908",
        "3X2 CHOCOLATE MILKA",
        "1,00",
        "2345,00",
        "DONUTS BLANCO 78GR",
        "(21,00)",
        "5070,00",
        "-1690,00",
        "2345,00",
        "7792360096825",
        "1,00",
        "3990,00",
        "CHOCOTRIO MILK BISCU",
        "(21,00)",
        "3990,00",
        "7891000437223",
        "24110,00",
        "SUBTOTAL",
        "-1690,00",
        "DESCUENTOS",
        "TOTAL",
        "$",
        "22420.00",
        "REGIMEN",
        "DE",
        "RANSPARENCIA",
        "FISCAL AL",
        "CONSUMIDOR (LEY 27.743)",
        "IVA CONTENIDO",
        "OTROS TRIBUTOS NACIONALES",
        "3891,07",
        "1090,9",
        "INDIRECTOS",
        "RECIBİ/MOS",
        "TARJETA",
        "Suma de sus pagos:",
        "22420.00",
        "$",
        "22420.00",
        "$ 0.00",
        "Su vuelto:",
        "CODIGO DE CAJERA",
        "317953",
    ]

    @Test func diaTomaElTotal() {
        #expect(TicketScannerService.parsear(lineas: dia).monto == 22420)
    }

    @Test func diaNoInventaProductos() {
        // El OCR mezcló la sección del medio: la cantidad, el precio
        // unitario y el nombre vienen en renglones sueltos y en distinto
        // orden según el producto. Ninguna lectura cierra con el subtotal
        // impreso, así que no se muestra detalle.
        #expect(TicketScannerService.parsear(lineas: dia).items.isEmpty)
    }

    // MARK: Nike — foto de peor calidad, el OCR come dígitos

    private let nike = [
        "Southbay S.R.L.",
        "Nike La Plata",
        "Bucursal RPRO: A010",
        "Camino Parque Centenario 2565",
        "entre Calle 508 y 507, B1800 B190000",
        "B1900CCE",
        "CUIT: 30-67816646-9",
        "ingresos Brutos: 30-6781 61",
        "-echa de Inicic de Actividades: 03/05/1996",
        "VA Responsable Inscripto",
        "ORIGINAL",
        "FACTURA-B (COD.006)",
        "N°: 00809-00030499",
        "Fecha: 06/05/2026",
        "Hora: 12:19:59 pm",
        "Cliente: Axel Morano",
        "Documento DNI N°: 44495809",
        "IVA: Consumidor Final",
        "Dirección: 4",
        "Localidad",
        "Provincia",
        "Articulo",
        "Cant Precio Bonif IVA Importe",
        "99909437635 1 $31,999 00 $31,99900 21% $0:00",
        "93060-011 Talia ONE SIZE -CAP ONE SIZE 011 BLACK WH",
        "196608/03242 1 $51999 00 $0:00",
        "21% $51,9990",
        "FB5541-410- Tald SMIK DF TRACK CLUB, 5,410 MID",
        "Total de Articulos: 2",
        "Descuentos",
        "Subtotal:",
        "Total:",
        "$31,999.00",
        "$51,999.00",
        "$51,999.00",
        "Regimen de transparencia fiscal al consumidor",
        "(Ley 27.743)",
        "IVA Contenido",
        "$9,024.62",
        "Otros Impuestos Nacionales Indirecto: $0.00",
        "Método de Pago",
        "T.Créd - MERCADO PAGO",
        "1 P - XXXXXXXXXXXX8747",
        "N° Auth.: 014406",
        "Monto",
        "$51.000.00",
        "Suma de Sus pagos",
        "$51,990.00",
        "COMPROBANTE ELECTRONICO",
    ]

    @Test func nikeTomaElTotalYNoElSubtotal() {
        // Los rótulos vienen en bloque —"Descuentos", "Subtotal:",
        // "Total:"— y los importes después. El de "Total:" es el último
        // de la columna.
        #expect(TicketScannerService.parsear(lineas: nike).monto == 51999)
    }

    @Test func nikeNoInventaProductos() {
        // Los renglones de artículo salieron con los dígitos comidos
        // ("$51999 00", "$0:00"): no hay lectura que cierre.
        #expect(TicketScannerService.parsear(lineas: nike).items.isEmpty)
    }

    @Test func kfcNoInventaProductos() {
        // Los precios vienen pegados al IVA — "(21.00) 4.000,00" — y en
        // otro orden que los nombres. Ninguna lectura cierra con el
        // total, así que no se muestra detalle en vez de mostrar
        // cualquier cosa.
        #expect(TicketScannerService.parsear(lineas: kfc).items.isEmpty)
    }
}
