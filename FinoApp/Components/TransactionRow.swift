import SwiftUI

/// Fila de movimiento: ícono de categoría, nombre, detalle y monto coloreado.
struct TransactionRow: View {

    let movimiento: Movimiento

    private var colorCategoria: Color {
        movimiento.categoria?.color ?? .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: movimiento.iconoCategoria)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(colorCategoria)
                .frame(width: 44, height: 44)
                .background(Circle().fill(colorCategoria.opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                Text(movimiento.nombre)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(movimiento.nombreCategoria)
                    Text("·")
                    Text(movimiento.fecha.diaYMes)
                    if let cuenta = movimiento.cuenta {
                        Text("·")
                        Text(cuenta.nombre).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if movimiento.esEnCuotas {
                    Text("Cuota \(movimiento.cuotaActual())/\(movimiento.cuotas) · \(movimiento.montoCuota.enMoneda)/mes")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.rellenoTerciario))
                }

                if movimiento.esCompartido {
                    Text("Compartido · Tu parte: \(movimiento.montoPropio.enMoneda)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.green.legible())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.legible().opacity(0.14)))
                }
            }

            Spacer(minLength: 8)

            Text(textoMonto)
                .font(.callout.bold())
                .monospacedDigit()
                .foregroundStyle(movimiento.tipo.color)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var textoMonto: String {
        let signo = movimiento.tipo == .gasto ? "-" : "+"
        return "\(signo)\(movimiento.monto.enMoneda)"
    }
}
