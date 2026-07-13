import SwiftUI

extension View {

    /// Estilo de tarjeta estándar de la app: fondo adaptativo, esquinas
    /// continuas bien redondeadas y sombra suave.
    func estiloTarjeta(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.fondoTarjeta)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            }
    }
}
