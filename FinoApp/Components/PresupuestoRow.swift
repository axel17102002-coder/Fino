import SwiftUI

/// Fila de presupuesto con barra de progreso que cambia de color según el avance.
struct PresupuestoRow: View {

    let presupuesto: Presupuesto
    let gastado: Double

    private var fraccion: Double {
        presupuesto.montoMensual > 0 ? gastado / presupuesto.montoMensual : 0
    }

    /// Verde por debajo del 75%, naranja al acercarse y rojo cuando se supera.
    private var colorEstado: Color {
        if fraccion >= 1 { .red } else if fraccion >= 0.75 { .orange } else { .green }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: presupuesto.categoria.icono)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(presupuesto.categoria.color)
                .frame(width: 38, height: 38)
                .background(Circle().fill(presupuesto.categoria.color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(presupuesto.categoria.nombre)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(Formatters.porcentaje(fraccion))
                        .font(.caption.bold())
                        .foregroundStyle(colorEstado)
                }

                ProgressView(value: min(fraccion, 1))
                    .tint(colorEstado)

                HStack {
                    Text(gastado.enMoneda)
                    Spacer()
                    Text("de \(presupuesto.montoMensual.enMoneda)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
