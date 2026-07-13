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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // Mismo fondo que las tarjetas: contrasta con el fondo verde
        // tanto en modo claro como en oscuro.
        .background {
            Capsule()
                .fill(Color.fondoTarjeta)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
        .animation(.snappy(duration: 0.2), value: texto.isEmpty)
    }
}
