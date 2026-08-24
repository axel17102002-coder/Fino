import SwiftUI

// Formato y colores del reloj. Vive en `FinoCompartido` porque lo usan
// los dos targets de watchOS: la app y la complicación de la esfera.
// La app de iPhone NO lo compila — ya tiene su propio `Color+Hex`.

// MARK: - Colores

extension Color {

    /// Crea un color a partir de un string hexadecimal `RRGGBB`.
    /// Es la misma lógica que `Color+Hex` del iPhone, copiada porque
    /// aquella importa UIKit para los colores dinámicos y acá no hacen
    /// falta: la pantalla del reloj siempre es oscura.
    init(hex: String) {
        let limpio = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var valor: UInt64 = 0
        Scanner(string: limpio).scanHexInt64(&valor)
        let r = Double((valor >> 16) & 0xFF) / 255
        let g = Double((valor >> 8) & 0xFF) / 255
        let b = Double(valor & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Verde de marca de Fino, el mismo del botón (+) del iPhone.
    static let verdeMarca = Color(hex: "366759")

    /// Crema de marca: el acento sobre fondo negro.
    static let crema = Color(hex: "FFE7C2")
}

// MARK: - Montos

extension SnapshotWatch {

    /// Formatea un monto con el símbolo y los decimales que mandó el
    /// iPhone, así el reloj no necesita conocer el enum `Moneda`.
    /// Respeta el modo privacidad igual que la app grande.
    func formatear(_ valor: Double) -> String {
        if montosOcultos { return "\(simboloMoneda) ••••" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = decimales
        formatter.minimumFractionDigits = decimales
        let numero = formatter.string(from: NSNumber(value: valor)) ?? "\(valor)"
        return "\(simboloMoneda) \(numero)"
    }

    /// Versión corta para los renglones angostos: `$ 1,9 M`.
    func formatearCorto(_ valor: Double) -> String {
        if montosOcultos { return "\(simboloMoneda) ••••" }

        let absoluto = abs(valor)
        let signo = valor < 0 ? "-" : ""
        switch absoluto {
        case 1_000_000...:
            let millones = absoluto / 1_000_000
            let texto = String(format: "%.1f", millones).replacingOccurrences(of: ".", with: ",")
            return "\(signo)\(simboloMoneda) \(texto) M"
        case 10_000...:
            return String(format: "%@%@ %.0f k", signo, simboloMoneda, absoluto / 1_000)
        default:
            return formatear(valor)
        }
    }

    /// Cuánto pesa una categoría sobre el total gastado del mes.
    func fraccion(_ monto: Double) -> Double {
        gastos > 0 ? monto / gastos : 0
    }
}

// MARK: - Fechas

extension Date {

    /// `hoy`, `ayer` o `12 ago`, que es todo lo que entra en un renglón
    /// de la lista de últimos movimientos.
    var cortaParaWatch: String {
        let calendario = Calendar.current
        if calendario.isDateInToday(self) { return String(localized: "hoy") }
        if calendario.isDateInYesterday(self) { return String(localized: "ayer") }
        return formatted(.dateTime.day().month(.abbreviated))
    }
}
