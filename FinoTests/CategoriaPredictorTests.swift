import Testing
import Foundation
@testable import Fino

/// Tests de la predicción de categoría a partir del historial.
@MainActor
struct CategoriaPredictorTests {

    private func gasto(_ nombre: String, _ categoria: CategoriaGasto, haceDias: Int = 0) -> Movimiento {
        Movimiento(
            tipo: .gasto,
            nombre: nombre,
            categoriaRaw: categoria.rawValue,
            monto: 100,
            fecha: Calendar.current.date(byAdding: .day, value: -haceDias, to: .now)!
        )
    }

    @Test func usaLaCategoriaMasFrecuenteDelComercio() {
        let historial = [
            gasto("Kiosco", .comida),
            gasto("Kiosco", .comida),
            gasto("Kiosco", .otros),
            gasto("Farmacia", .salud),
        ]
        #expect(CategoriaPredictorService.predecir(nombre: "Kiosco", entre: historial) == CategoriaGasto.comida.rawValue)
    }

    @Test func ignoraMayusculasYAcentos() {
        let historial = [gasto("Café Martínez", .comida)]
        #expect(CategoriaPredictorService.predecir(nombre: "CAFE MARTINEZ", entre: historial) == CategoriaGasto.comida.rawValue)
    }

    @Test func coincidePorPrefijo() {
        // "Carrefour" aprende de "Carrefour Express".
        let historial = [gasto("Carrefour Express", .supermercado)]
        #expect(CategoriaPredictorService.predecir(nombre: "Carrefour", entre: historial) == CategoriaGasto.supermercado.rawValue)
    }

    @Test func empateLoDesempataLaMasReciente() {
        let historial = [
            gasto("Shell", .otros, haceDias: 30),
            gasto("Shell", .transporte, haceDias: 1),
        ]
        #expect(CategoriaPredictorService.predecir(nombre: "Shell", entre: historial) == CategoriaGasto.transporte.rawValue)
    }

    @Test func sinHistorialNoOpina() {
        #expect(CategoriaPredictorService.predecir(nombre: "Comercio Nuevo", entre: []) == nil)
    }

    @Test func nombresMuyCortosNoPredicen() {
        let historial = [gasto("La", .comida)]
        #expect(CategoriaPredictorService.predecir(nombre: "La", entre: historial) == nil)
    }

    @Test func losIngresosNoEnsucianLaPrediccion() {
        let historial = [
            Movimiento(tipo: .ingreso, nombre: "Kiosco", categoriaRaw: CategoriaIngreso.sueldo.rawValue, monto: 100)
        ]
        #expect(CategoriaPredictorService.predecir(nombre: "Kiosco", entre: historial) == nil)
    }
}
