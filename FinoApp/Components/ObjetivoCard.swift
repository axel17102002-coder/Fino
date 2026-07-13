import SwiftUI

/// Tarjeta de objetivo de ahorro con barra de progreso.
struct ObjetivoCard: View {

    let objetivo: ObjetivoAhorro

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: objetivo.icono)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(objetivo.color)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(objetivo.color.opacity(0.15)))
                Spacer()
                if objetivo.completado {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(objetivo.nombre)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text(objetivo.ahorradoFormateado)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ProgressView(value: objetivo.progreso)
                .tint(objetivo.color)

            HStack {
                Text(Formatters.porcentaje(objetivo.progreso))
                    .font(.caption.bold())
                    .foregroundStyle(objetivo.color)
                Spacer()
                Text("Meta \(objetivo.metaFormateadaCompacta)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 190, alignment: .leading)
        .estiloTarjeta()
        .accessibilityElement(children: .combine)
    }
}
