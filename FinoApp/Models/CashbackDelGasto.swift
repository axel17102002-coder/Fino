import Foundation

/// El cashback que devuelve un gasto, cargado junto con él.
///
/// Existe para no tener que dar de alta dos veces la misma compra: antes
/// se cargaba el gasto y después, a mano, el movimiento de cashback con
/// la misma fecha y la misma tarjeta.
struct CashbackDelGasto {

    /// Cómo se expresa la devolución. Las promociones se anuncian de las
    /// dos formas —"20% de reintegro" o "te devolvemos $5.000"— y obligar
    /// a convertir una en la otra es justo el trabajo que se quiere evitar.
    enum Modo: String, CaseIterable, Identifiable {
        case porcentaje
        case monto

        var id: String { rawValue }

        var nombre: String {
            switch self {
            case .porcentaje: String(localized: "Porcentaje")
            case .monto: String(localized: "Monto")
            }
        }
    }

    var modo: Modo = .porcentaje
    /// Lo tecleado: el porcentaje, o el monto en la moneda del gasto.
    var texto: String = ""

    /// Cuánto se devuelve, en la misma moneda en que se cargó el gasto.
    ///
    /// Devuelve `nil` cuando todavía no hay un número usable, para poder
    /// distinguir "no cargó nada" de "cargó cero".
    func monto(sobre gasto: Double) -> Double? {
        guard let valor = Formatters.parsearMonto(texto), valor > 0, gasto > 0 else { return nil }
        switch modo {
        case .monto:
            // Más que el gasto no puede volver: sería una ganancia, no un
            // reintegro, y lo más probable es un error de tipeo.
            return min(valor, gasto)
        case .porcentaje:
            guard valor <= 100 else { return nil }
            return gasto * valor / 100
        }
    }
}
