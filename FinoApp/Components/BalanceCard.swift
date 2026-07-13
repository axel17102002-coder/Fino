import SwiftUI

/// Panel principal del Dashboard: balance, métricas clave y últimos movimientos.
struct BalanceCard: View {

    let balance: Double
    let ingresos: Double
    let gastos: Double
    let cashback: Double
    let ultimosMovimientos: [Movimiento]

    private var movimientosMostrados: [Movimiento] {
        Array(ultimosMovimientos.prefix(3))
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            contenidoHorizontal
            contenidoVertical
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var contenidoHorizontal: some View {
        HStack(alignment: .top, spacing: 18) {
            bloqueBalance
                .frame(minWidth: 132, maxWidth: .infinity, alignment: .leading)

            bloqueMetricas
                .frame(width: 138, alignment: .leading)

            bloqueMovimientos
                .frame(width: 150, alignment: .leading)
        }
    }

    private var contenidoVertical: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                bloqueBalance
                    .frame(maxWidth: .infinity, alignment: .leading)

                bloqueMetricas
                    .frame(width: 138, alignment: .leading)
            }

            if !movimientosMostrados.isEmpty {
                Divider()
                bloqueMovimientos
            }
        }
    }

    private var bloqueBalance: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Resumen de \(Date.now.nombreMes)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
            }

            Text(balance.enMoneda)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .contentTransition(.numericText())

            HStack(spacing: 8) {
                Image(systemName: balance >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(balance >= 0 ? .green : .red)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill((balance >= 0 ? Color.green : Color.red).opacity(0.14)))

                Text(balance >= 0 ? "Balance positivo" : "Balance negativo")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bloqueMetricas: some View {
        VStack(alignment: .leading, spacing: 12) {
            indicador(String(localized: "Gastos"), valor: gastos, icono: "arrow.up.right", color: .red)
            indicador(String(localized: "Ingresos"), valor: ingresos, icono: "arrow.down.left", color: .green)
            indicador(String(localized: "Cashback"), valor: cashback, icono: "creditcard.fill", color: .orange)
        }
    }

    @ViewBuilder
    private var bloqueMovimientos: some View {
        if !movimientosMostrados.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Últimos movimientos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(movimientosMostrados) { movimiento in
                        movimientoCompacto(movimiento)
                    }
                }
            }
        }
    }

    private func indicador(_ titulo: String, valor: Double, icono: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icono)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(valor.enMoneda)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private func movimientoCompacto(_ movimiento: Movimiento) -> some View {
        HStack(spacing: 8) {
            Image(systemName: movimiento.iconoCategoria)
                .font(.caption.weight(.semibold))
                .foregroundStyle(movimiento.categoria?.color ?? .gray)
                .frame(width: 24, height: 24)
                .background(Circle().fill((movimiento.categoria?.color ?? .gray).opacity(0.14)))

            Text(movimiento.nombre)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(textoMonto(movimiento))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(movimiento.tipo.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func textoMonto(_ movimiento: Movimiento) -> String {
        let signo = movimiento.tipo == .gasto ? "-" : "+"
        return "\(signo)\(movimiento.monto.enMoneda)"
    }
}

#Preview {
    BalanceCard(
        balance: 647_800,
        ingresos: 2_500_000,
        gastos: 1_900_000,
        cashback: 47_800,
        ultimosMovimientos: []
    )
    .padding()
}
