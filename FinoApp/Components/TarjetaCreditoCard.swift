import SwiftUI

/// Tarjeta de crédito estilo Apple Wallet: consumo, disponible, cierre y vencimiento.
struct TarjetaCreditoCard: View {

    let cuenta: Cuenta
    /// En carruseles usa un ancho fijo; expandida ocupa todo el ancho disponible.
    var expandida: Bool = false

    private var consumido: Double {
        CalculosService.consumoActual(de: cuenta)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cuenta.nombre)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if !cuenta.banco.isEmpty {
                        Text(cuenta.banco)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Spacer()
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.white.opacity(0.9))
            }

            if !cuenta.ultimosDigitos.isEmpty {
                Text("•••• \(cuenta.ultimosDigitos)")
                    .font(.subheadline.weight(.medium))
                    .monospaced()
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom) {
                    dato(String(localized: "Consumido"), valor: consumido.enMoneda, alineado: .leading)
                    Spacer()
                    if let disponible = CalculosService.disponible(de: cuenta) {
                        dato(String(localized: "Disponible"), valor: disponible.enMoneda, alineado: .trailing)
                    }
                }
                if cuenta.limite > 0 {
                    ProgressView(value: min(consumido / cuenta.limite, 1))
                        .tint(.white)
                }
            }

            HStack {
                if let cierre = cuenta.proximoCierre() {
                    dato(String(localized: "Cierre"), valor: cierre.diaYMes, alineado: .leading)
                }
                Spacer()
                if let vencimiento = cuenta.proximoVencimiento() {
                    dato(String(localized: "Vencimiento"), valor: vencimiento.diaYMes, alineado: .trailing)
                }
            }
        }
        .padding(18)
        .frame(width: expandida ? nil : 300, alignment: .leading)
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

    private func dato(_ titulo: String, valor: String, alineado: HorizontalAlignment) -> some View {
        VStack(alignment: alineado, spacing: 2) {
            Text(titulo)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
            Text(valor)
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}
