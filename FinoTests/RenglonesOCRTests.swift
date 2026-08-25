import Testing
import Foundation
@testable import Fino

/// Armado de renglones a partir de dónde está cada fragmento en la foto.
///
/// Es la parte del escaneo que sí se puede probar sin una imagen: recibe
/// fragmentos con sus coordenadas y devuelve los renglones. Las cajas van
/// en coordenadas de Vision —normalizadas y con el origen abajo a la
/// izquierda—, así que más `y` es más arriba en el ticket.
struct RenglonesOCRTests {

    private func fragmento(
        _ texto: String,
        x: CGFloat,
        y: CGFloat,
        ancho: CGFloat = 0.2,
        alto: CGFloat = 0.02
    ) -> TicketScannerService.FragmentoOCR {
        .init(texto: texto, caja: CGRect(x: x, y: y, width: ancho, height: alto))
    }

    @Test func apareaElPrecioConSuProductoPorLaAltura() {
        // Dos columnas: descripción a la izquierda, importe a la derecha.
        let leidos = [
            fragmento("LECHE ENTERA 1L", x: 0.05, y: 0.80),
            fragmento("1.250,00", x: 0.75, y: 0.80),
        ]
        #expect(TicketScannerService.renglones(de: leidos) == ["LECHE ENTERA 1L 1.250,00"])
    }

    @Test func elOrdenEnQueVienenNoImporta() {
        // Este es el bug que se veía con flash: Vision entrega los
        // fragmentos en otro orden y el precio terminaba en el producto
        // equivocado.
        let desordenados = [
            fragmento("990,00", x: 0.75, y: 0.70),
            fragmento("LECHE ENTERA 1L", x: 0.05, y: 0.80),
            fragmento("PAN LACTAL", x: 0.05, y: 0.70),
            fragmento("1.250,00", x: 0.75, y: 0.80),
        ]
        #expect(TicketScannerService.renglones(de: desordenados) == [
            "LECHE ENTERA 1L 1.250,00",
            "PAN LACTAL 990,00",
        ])
    }

    @Test func vanDeArribaHaciaAbajo() {
        let leidos = [
            fragmento("ABAJO", x: 0.05, y: 0.10),
            fragmento("ARRIBA", x: 0.05, y: 0.90),
            fragmento("MEDIO", x: 0.05, y: 0.50),
        ]
        #expect(TicketScannerService.renglones(de: leidos) == ["ARRIBA", "MEDIO", "ABAJO"])
    }

    @Test func unaDiferenciaChicaDeAlturaSigueSiendoElMismoRenglon() {
        // El papel arrugado y la foto en ángulo desalinean los fragmentos
        // de un mismo renglón unos pocos píxeles.
        let leidos = [
            fragmento("GASEOSA 2.25L", x: 0.05, y: 0.600),
            fragmento("2.480,00", x: 0.75, y: 0.604),
        ]
        #expect(TicketScannerService.renglones(de: leidos).count == 1)
    }

    @Test func rengloneseDistintosNoSeMezclan() {
        // Separados por más de su propia altura: son dos renglones.
        let leidos = [
            fragmento("PRIMERO", x: 0.05, y: 0.60),
            fragmento("SEGUNDO", x: 0.05, y: 0.50),
        ]
        #expect(TicketScannerService.renglones(de: leidos).count == 2)
    }

    @Test func unPrecioMasGrandeQueLaDescripcionSigueEnSuRenglon() {
        // El total suele ir en letra más grande que el resto. Comparando
        // distancia entre centros en vez de solapamiento, esto se
        // separaba en dos renglones.
        let leidos = [
            fragmento("TOTAL", x: 0.05, y: 0.300, alto: 0.02),
            fragmento("19.431,70", x: 0.70, y: 0.295, alto: 0.035),
        ]
        #expect(TicketScannerService.renglones(de: leidos) == ["TOTAL 19.431,70"])
    }

    @Test func tresColumnasSeOrdenanDeIzquierdaADerecha() {
        let leidos = [
            fragmento("2.480,00", x: 0.78, y: 0.40),
            fragmento("YOGUR", x: 0.05, y: 0.40),
            fragmento("2 x 1.240,00", x: 0.40, y: 0.40),
        ]
        #expect(TicketScannerService.renglones(de: leidos) == ["YOGUR 2 x 1.240,00 2.480,00"])
    }

    @Test func sinFragmentosNoHayRenglones() {
        #expect(TicketScannerService.renglones(de: []).isEmpty)
    }
}
