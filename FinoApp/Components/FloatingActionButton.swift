import SwiftUI

/// Botón flotante (+) para agregar movimientos, con estilo Liquid Glass.
/// Reposa en la muesca circular de `BarraInferiorView`.
struct FloatingActionButton: View {
    let accion: () -> Void

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            accion()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color(hex: "366759"))
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(EfectoVidrioCircular())
        .accessibilityLabel("Agregar movimiento")
    }
}

/// Liquid Glass nativo en iOS 26+; en versiones anteriores, material
/// translúcido con borde sutil que imita el mismo aspecto.
private struct EfectoVidrioCircular: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                }
        }
    }
}
