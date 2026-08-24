import SwiftUI
import UIKit

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
        .modifier(VidrioDeBusqueda())
        .animation(.snappy(duration: 0.2), value: texto.isEmpty)
    }
}

/// Cápsula de vidrio para la barra de búsqueda.
///
/// Va en `.clear` y no en `.regular`, igual que la barra inferior: la
/// variante clara casi no difumina, así que se comporta como una lente y
/// deja ver el contenido de atrás en vez de tapar con un vidrio
/// esmerilado. Sin velo debajo: cualquier relleno la vuelve a convertir
/// en una cápsula opaca, y lo que le da forma es el borde del propio
/// material.
///
/// `interactive()` es lo que la hace sentir Liquid Glass de verdad: al
/// tocarla el vidrio se hunde y la luz del borde acompaña al dedo.
private struct VidrioDeBusqueda: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.clear.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}
