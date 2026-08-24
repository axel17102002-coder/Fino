import SwiftUI

/// Qué tenés invertido, cuánto vale y dónde está.
///
/// Todo en dólares aunque haya tenencias en pesos: sumar dos monedas no
/// da un número. El donut reparte por tenencia y al lado va el reparto
/// por clase, que responden dos preguntas distintas —cuánto hay en cada
/// cosa y cuánto en cada tipo de cosa— sin necesitar dos tarjetas.
struct InversionesCard: View {

    let cartera: Cartera

    @State private var seleccion: String?

    var body: some View {
        if cartera.ordenadas.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                encabezado

                HStack(alignment: .center, spacing: 12) {
                    DonutChart(
                        segmentos: cartera.segmentos,
                        seleccion: $seleccion,
                        tituloCentro: String(localized: "Total"),
                        valorCentro: cartera.total,
                        moneda: .usd,
                        altura: 150,
                        compacto: true
                    )
                    .frame(width: 150)

                    porClase
                }

                if !cartera.porVencer.isEmpty {
                    avisoDeVencimientos
                }

                Divider().overlay(Color.primary.opacity(0.12))

                VStack(spacing: 12) {
                    ForEach(cartera.ordenadas, id: \.inversion.id) { item in
                        fila(item.inversion, dolares: item.dolares)
                    }
                }
            }
            .estiloTarjetaVidrio()
        }
    }

    private var encabezado: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Inversiones")
                    .font(.headline)
                if cartera.faltaCotizacion {
                    // El total está incompleto y hay que decirlo: mostrar
                    // un número al que le falta una parte, sin avisar, es
                    // peor que no mostrarlo.
                    Text("Sin cotización del dólar: faltan las tenencias en pesos.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 8)
            Text(Formatters.moneda(cartera.total, moneda: .usd))
                .font(.title3.bold())
                .monospacedDigit()
        }
    }

    private var porClase: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(cartera.porClase, id: \.tipo) { clase in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(clase.tipo.color)
                            .frame(width: 8, height: 8)
                        Text(clase.tipo.nombre)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(Int((clase.proporcion * 100).rounded()))%")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    Text(Formatters.moneda(clase.dolares, moneda: .usd))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var avisoDeVencimientos: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(cartera.porVencer, id: \.id) { inversion in
                Label(
                    inversion.diasParaVencer == 0
                        ? String(localized: "\(inversion.nombre) vence hoy")
                        : String(localized: "\(inversion.nombre) vence en \(inversion.diasParaVencer ?? 0) días"),
                    systemImage: "clock.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
    }

    private func fila(_ inversion: Inversion, dolares: Double) -> some View {
        let proporcion = cartera.total > 0 ? dolares / cartera.total : 0

        return HStack(spacing: 12) {
            Image(systemName: inversion.tipo.icono)
                .font(.caption)
                .foregroundStyle(inversion.tipo.color)
                .frame(width: 30, height: 30)
                .background(Circle().fill(inversion.tipo.color.opacity(0.18)))

            VStack(alignment: .leading, spacing: 1) {
                Text(inversion.nombre)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitulo(de: inversion))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(Formatters.moneda(dolares, moneda: .usd))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                Text("\(Int((proporcion * 100).rounded()))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Dónde está y, en las de pesos, cuánto es en su moneda: el total va
    /// en dólares pero el plazo fijo lo tenés en la cabeza en pesos.
    private func subtitulo(de inversion: Inversion) -> String {
        var partes: [String] = []
        if !inversion.donde.isEmpty { partes.append(inversion.donde) }
        if inversion.moneda != .usd {
            partes.append(Formatters.moneda(inversion.valor, moneda: inversion.moneda))
        } else if let cantidad = inversion.cantidad, inversion.tipo.usaTicker {
            // Sin decimales cuando es entero: "10 AAPL" y no "10,0".
            partes.append(cantidad.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(cantidad))
                : String(format: "%g", cantidad))
        }
        return partes.joined(separator: " · ")
    }
}
