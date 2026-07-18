import SwiftUI

/// Card de una cuenta (no tarjeta) para el carrusel del Dashboard:
/// muestra cuánto se gastó con esa cuenta en el mes y su saldo actual.
struct CuentaResumenCard: View {

    let cuenta: Cuenta
    /// En carruseles usa un ancho fijo; expandida ocupa todo el ancho disponible.
    var expandida: Bool = false

    private var gastoDelMes: Double {
        CalculosService.gastoDelMes(de: cuenta)
    }

    private var saldo: Double {
        CalculosService.saldo(de: cuenta)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cuenta.nombre)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(cuenta.banco.isEmpty ? cuenta.tipo.nombre : cuenta.banco)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: cuenta.icono)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gastado este mes")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(gastoDelMes.enMoneda)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Saldo")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(saldo.enMoneda)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(18)
        .frame(width: expandida ? nil : 230, height: expandida ? nil : 120, alignment: .leading)
        .frame(maxWidth: expandida ? .infinity : nil, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cuenta.color, cuenta.color.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: cuenta.color.opacity(0.35), radius: 10, y: 5)
        }
        .accessibilityElement(children: .combine)
    }
}
