import SwiftUI

/// Fila con una observación breve sobre las finanzas del usuario.
/// Se agrupa en una lista continua dentro de una sola tarjeta.
struct InsightCard: View {

    let insight: Insight

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icono)
                .font(.body)
                .foregroundStyle(insight.color)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(insight.color.opacity(0.15)))

            Text(insight.texto)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
