import SwiftUI

/// Tarjeta resumen del Dashboard: ícono, título, monto y subtítulo opcional.
struct SummaryCard: View {

    let titulo: String
    let monto: Double
    var subtitulo: String? = nil
    let icono: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icono)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(color.opacity(0.15)))

            Text(titulo)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(monto.enMoneda)
                .font(.title3.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())

            Text(subtitulo ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .estiloTarjeta()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SummaryCard(
        titulo: String(localized: "Gastos"),
        monto: 1_900_000,
        subtitulo: String(localized: "76% de tus ingresos"),
        icono: "arrow.up.right.circle.fill",
        color: .red
    )
    .padding()
}
