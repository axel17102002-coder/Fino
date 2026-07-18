import Foundation

/// Formateadores centralizados de la app.
enum Formatters {

    /// Moneda elegida por el usuario en Configuración.
    static var monedaActual: Moneda {
        let raw = UserDefaults.standard.string(forKey: Preferencias.claveMoneda) ?? Moneda.ars.rawValue
        return Moneda(rawValue: raw) ?? .ars
    }

    /// Formatea un monto en la moneda indicada (o la global si no se pasa).
    /// Modo privacidad (el ojito del Dashboard): todos los montos de la
    /// app se muestran tapados.
    static var montosOcultos: Bool {
        UserDefaults.standard.bool(forKey: Preferencias.claveMontosOcultos)
    }

    static func moneda(_ valor: Double, moneda: Moneda? = nil) -> String {
        let monedaSeleccionada = moneda ?? monedaActual
        if montosOcultos { return "\(monedaSeleccionada.simbolo) ••••" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = monedaSeleccionada.rawValue
        formatter.currencySymbol = "\(monedaSeleccionada.simbolo) "
        formatter.maximumFractionDigits = monedaSeleccionada.decimales
        formatter.minimumFractionDigits = monedaSeleccionada == .ars ? 0 : monedaSeleccionada.decimales

        return formatter.string(from: NSNumber(value: valor))
            ?? "\(monedaSeleccionada.simbolo) \(valor)"
    }

    /// Versión compacta para ejes de gráficos, ej: `1,9 M` o `250 k`.
    static func monedaCompacta(_ valor: Double, moneda: Moneda? = nil) -> String {
        let moneda = moneda ?? monedaActual
        if montosOcultos { return "\(moneda.simbolo) ••••" }
        let absoluto = abs(valor)
        let signo = valor < 0 ? "-" : ""
        let simbolo = moneda.simbolo

        switch moneda {
        case .ars:
            switch absoluto {
            case 1_000_000...:
                let millones = absoluto / 1_000_000
                let texto = millones.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", millones)
                    : String(format: "%.1f", millones).replacingOccurrences(of: ".", with: ",")
                return "\(signo)\(texto) M"
            case 1_000...:
                return String(format: "%@%.0f k", signo, absoluto / 1_000)
            default:
                return String(format: "%@%.0f", signo, absoluto)
            }
        case .usd, .eur:
            switch absoluto {
            case 1_000_000...:
                return String(format: "%@%@%.1fM", signo, simbolo, absoluto / 1_000_000)
            case 1_000...:
                return String(format: "%@%@%.0fk", signo, simbolo, absoluto / 1_000)
            default:
                return Formatters.moneda(valor, moneda: moneda)
            }
        }
    }

    /// Texto editable para un campo de monto según la moneda del objetivo.
    static func montoEditable(_ valor: Double, moneda: Moneda) -> String {
        if moneda.decimales == 0 {
            return String(format: "%.0f", valor)
        }
        return String(format: "%.2f", valor)
    }

    /// Parsea un monto escrito por el usuario aceptando formato argentino
    /// ("1.900.000,50") o plano ("1900000.50").
    static func parsearMonto(_ texto: String) -> Double? {
        var limpio = texto.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return nil }
        if limpio.contains(",") {
            limpio = limpio
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }
        return Double(limpio)
    }

    /// Porcentaje sin decimales a partir de una fracción (0.72 → `72%`).
    static func porcentaje(_ fraccion: Double) -> String {
        String(format: "%.0f%%", fraccion * 100)
    }

    /// Porcentaje con signo para variaciones (+18% / -5%).
    static func variacion(_ fraccion: Double) -> String {
        String(format: "%+.0f%%", fraccion * 100)
    }
}
