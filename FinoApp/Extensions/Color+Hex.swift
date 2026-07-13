import SwiftUI
import UIKit

/// Paleta compartida para elegir el color de cuentas, tarjetas,
/// objetivos y categorías personalizadas.
enum Paleta {
    static let colores = [
        "EF4444", "DC2626", "E11D48", "F87171",
        "EC4899", "DB2777", "F472B6", "C084FC",
        "F97316", "EA580C", "FB923C", "F59E0B",
        "FBBF24", "EAB308", "A16207", "92400E",
        "22C55E", "16A34A", "84CC16", "10B981",
        "366759", "14B8A6", "06B6D4", "0EA5E9",
        "38BDF8", "3B82F6", "2563EB", "6366F1",
        "4F46E5", "8B5CF6", "A855F7", "7C3AED",
        "78716C", "64748B", "475569", "1E293B"
    ]
}

extension Color {

    /// Crea un color a partir de un string hexadecimal `RRGGBB`.
    init(hex: String) {
        let limpio = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var valor: UInt64 = 0
        Scanner(string: limpio).scanHexInt64(&valor)
        let r = Double((valor >> 16) & 0xFF) / 255
        let g = Double((valor >> 8) & 0xFF) / 255
        let b = Double(valor & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Fondo de las tarjetas de la app, adaptado a modo claro/oscuro.
    static var fondoTarjeta: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    /// Verde de marca de la app (el mismo del botón +).
    static var verdeMarca: Color {
        Color(hex: "366759")
    }

    // "Crema" (#FFE7C2) y "VerdeOscuro" (#305E51) viven en Assets:
    // Xcode genera solo los accesos Color.crema y Color.verdeOscuro.

    /// Fondo general de las pantallas: verde de marca fijo.
    /// El modo claro/oscuro cambia solo las tarjetas, no este fondo.
    static var fondoPantalla: Color {
        verdeMarca
    }

    /// Relleno neutro para chips, cápsulas y fondos de íconos.
    static var rellenoTerciario: Color {
        Color(uiColor: .tertiarySystemFill)
    }
}
