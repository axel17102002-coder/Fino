import SwiftUI

extension View {
    /// Aparición escalonada: la vista entra con un fundido y un leve
    /// desplazamiento hacia arriba, retrasada según su posición.
    /// Se anula con "Reducir movimiento" activado en iOS.
    func entradaEscalonada(_ indice: Int, visible: Bool) -> some View {
        modifier(EntradaEscalonada(indice: indice, visible: visible))
    }
}

private struct EntradaEscalonada: ViewModifier {
    let indice: Int
    let visible: Bool

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    func body(content: Content) -> some View {
        if reducirMovimiento {
            content
        } else {
            content
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 14)
                .animation(
                    .easeOut(duration: 0.42).delay(Double(indice) * 0.07),
                    value: visible
                )
        }
    }
}
