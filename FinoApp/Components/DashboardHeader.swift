import SwiftUI

/// Encabezado del Dashboard: saludo personalizado con el nombre del usuario
/// (configurable en Configuración) o según la hora si no hay nombre.
struct DashboardHeader: View {

    @AppStorage(Preferencias.claveNombre) private var nombre: String = ""

    var body: some View {
        // El logo vive en la franja fija de DashboardView; acá queda
        // solo el saludo, que scrollea con el contenido.
        VStack(alignment: .leading, spacing: 4) {
            Text(saludo)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Así viene tu mes 🚀")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var saludo: String {
        let limpio = nombre.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return saludoPorHora }
        return String(localized: "¡Hola \(limpio)! \(emojiPorHora)")
    }

    private var saludoPorHora: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 6..<13: String(localized: "¡Buen día! 👋")
        case 13..<20: String(localized: "¡Buenas tardes! 👋")
        default: String(localized: "¡Buenas noches! 🌙")
        }
    }

    private var emojiPorHora: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 6..<20: "👋"
        default: "🌙"
        }
    }
}

#Preview {
    DashboardHeader()
        .padding()
        .background(Color.fondoPantalla)
}
