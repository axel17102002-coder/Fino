import UIKit

/// Feedback háptico centralizado.
enum Haptics {

    static func impacto(_ estilo: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: estilo).impactOccurred()
    }

    static func seleccion() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func exito() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func advertencia() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
