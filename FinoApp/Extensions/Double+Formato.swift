import Foundation

extension Double {

    /// Monto formateado en la moneda elegida, ej: `$ 1.900.000`.
    var enMoneda: String {
        Formatters.moneda(self)
    }

    /// Monto compacto para ejes y espacios chicos, ej: `1,9 M`.
    var enMonedaCompacta: String {
        Formatters.monedaCompacta(self)
    }
}
