import SwiftUI

/// Lista compacta de los últimos movimientos, para el pie de la card
/// principal del inicio. Vivía dentro de `BalanceCard`, pero al pasar el
/// donut al medio quedó como bloque aparte y separarla fue la forma de
/// poder ordenarla desde el Dashboard.
struct UltimosMovimientos: View {

    let movimientos: [Movimiento]
    /// Cuántos se muestran como máximo.
    var maximo: Int = 3

    private var mostrados: [Movimiento] {
        Array(movimientos.prefix(maximo))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Últimos movimientos")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(mostrados) { movimiento in
                    fila(movimiento)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func fila(_ movimiento: Movimiento) -> some View {
        HStack(spacing: 8) {
            Image(systemName: movimiento.iconoCategoria)
                .font(.caption.weight(.semibold))
                .foregroundStyle((movimiento.categoria?.color ?? .gray).legible())
                .frame(width: 24, height: 24)
                .background(Circle().fill((movimiento.categoria?.color ?? .gray).legible().opacity(0.18)))

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
