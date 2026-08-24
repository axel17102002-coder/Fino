import Foundation
import SwiftUI

/// Las inversiones vistas como un todo, ya llevadas a una sola moneda.
///
/// Todo se muestra en dólares aunque haya tenencias en pesos —un plazo
/// fijo, una cuenta remunerada—: sumar dos monedas no da un número, y el
/// dólar es la unidad en la que están la mayoría.
struct Cartera {

    /// Cuántos dólares vale una unidad de cada moneda. El dólar no está:
    /// vale uno por definición.
    ///
    /// Es un diccionario y no una sola cotización porque las tenencias
    /// pueden estar en pesos, en euros o en dólares a la vez, y con un
    /// único "pesos por dólar" las de euros quedaban afuera del total sin
    /// que nadie lo notara.
    let tasasADolar: [Moneda: Double]
    let tenencias: [Inversion]

    /// Cuántas porciones tiene el donut antes de agrupar. Más de seis y
    /// las de abajo quedan como rayitas ilegibles.
    static let porcionesVisibles = 6

    init(_ tenencias: [Inversion], tasasADolar: [Moneda: Double] = [:]) {
        self.tenencias = tenencias
        self.tasasADolar = tasasADolar
    }

    /// Valor en dólares de una tenencia. Las que ya están en dólares
    /// pasan tal cual.
    func enDolares(_ inversion: Inversion) -> Double? {
        guard inversion.moneda != .usd else { return inversion.valor }
        guard let tasa = tasasADolar[inversion.moneda] else { return nil }
        return inversion.valor * tasa
    }

    /// Hay tenencias en pesos que no se pueden convertir. La card lo dice
    /// en vez de mostrar un total al que le falta una parte sin avisar.
    var faltaCotizacion: Bool {
        tenencias.contains { enDolares($0) == nil }
    }

    var total: Double {
        tenencias.compactMap { enDolares($0) }.reduce(0, +)
    }

    /// Cada tenencia con su valor, de mayor a menor.
    var ordenadas: [(inversion: Inversion, dolares: Double)] {
        tenencias
            .compactMap { inversion in
                enDolares(inversion).map { (inversion, $0) }
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    /// Reparto por clase, de mayor a menor: acciones, cripto, plazo fijo.
    var porClase: [(tipo: TipoInversion, dolares: Double, proporcion: Double)] {
        let agrupadas = Dictionary(grouping: ordenadas) { $0.inversion.tipo }
        let total = self.total
        guard total > 0 else { return [] }
        return agrupadas
            .map { tipo, items in
                let suma = items.reduce(0) { $0 + $1.dolares }
                return (tipo, suma, suma / total)
            }
            .sorted { $0.1 > $1.1 }
    }

    /// Porciones del donut: las más grandes con su ticker y el resto
    /// juntas en "Otras".
    ///
    /// El color sale de la clase, aclarándose según la posición, para que
    /// el donut se lea como bloques —un arco azul de acciones, uno
    /// naranja de cripto— y no como doce colores sueltos.
    var segmentos: [SegmentoDonut] {
        let items = ordenadas
        guard !items.isEmpty else { return [] }

        let visibles = items.prefix(Self.porcionesVisibles)
        var posicionEnClase: [TipoInversion: Int] = [:]

        var resultado = visibles.map { item -> SegmentoDonut in
            let posicion = posicionEnClase[item.inversion.tipo, default: 0]
            posicionEnClase[item.inversion.tipo] = posicion + 1
            return SegmentoDonut(
                id: item.inversion.id.uuidString,
                nombre: item.inversion.nombre,
                color: item.inversion.tipo.color.opacity(1 - Double(posicion) * 0.18),
                monto: item.dolares
            )
        }

        let resto = items.dropFirst(Self.porcionesVisibles)
        if !resto.isEmpty {
            resultado.append(SegmentoDonut(
                id: "otras",
                nombre: String(localized: "Otras"),
                color: .gray,
                monto: resto.reduce(0) { $0 + $1.dolares }
            ))
        }
        return resultado
    }

    /// Plazos fijos que vencen dentro de la semana, para avisarlo.
    var porVencer: [Inversion] {
        tenencias
            .filter { ($0.diasParaVencer ?? .max) <= 7 }
            .sorted { ($0.diasParaVencer ?? 0) < ($1.diasParaVencer ?? 0) }
    }
}

extension Cartera {

    /// Pide una cotización por cada moneda que aparezca en las tenencias,
    /// y ninguna de más: con todas las tenencias en dólares no se toca la
    /// red. El dólar no se pide porque vale uno.
    static func tasas(para tenencias: [Inversion]) async -> [Moneda: Double] {
        var resultado: [Moneda: Double] = [:]
        for moneda in Set(tenencias.map(\.moneda)) where moneda != .usd {
            if let tasa = await ExchangeRateService.tasa(de: moneda, a: .usd) {
                resultado[moneda] = tasa
            }
        }
        return resultado
    }
}
