import SwiftUI

/// Barra de búsqueda con estilo cápsula y botón para borrar el texto.
struct SearchBar: View {

    @Binding var texto: String
    var placeholder: String = String(localized: "Buscar")

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $texto)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !texto.isEmpty {
                Button {
                    texto = ""
                    Haptics.impacto()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        // Mismo fondo que las tarjetas, con un borde sutil en vez de una
        // sombra marcada: así se integra con la lista en vez de flotar.
        .background {
            Capsule()
                .fill(Color.fondoTarjeta)
                .overlay(
                    Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
        .animation(.snappy(duration: 0.2), value: texto.isEmpty)
    }
}
