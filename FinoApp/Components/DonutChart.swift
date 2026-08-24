import SwiftUI
import Charts

/// Sección del gráfico de dona del Dashboard (una categoría de gasto).
struct SegmentoDonut: Identifiable {
    let id: String
    let nombre: String
    let color: Color
    let monto: Double
}

/// Dona interactiva hecha con Swift Charts: al tocar una sección se resalta
/// y el centro muestra el monto correspondiente con una transición animada.
struct DonutChart: View {

    let segmentos: [SegmentoDonut]
    @Binding var seleccion: String?
    var tituloCentro: String = "Gastos"
    var valorCentro: Double = 0
    /// Moneda en la que están los montos. Sin esto el centro los formatea
    /// con la moneda de la app, y en Inversiones —que va todo en dólares—
    /// mostraba el símbolo de pesos sobre cifras en dólares.
    var moneda: Moneda?
    var altura: CGFloat = 250
    var compacto = false

    @State private var anguloSeleccionado: Double?

    var body: some View {
        Chart(segmentos) { segmento in
            SectorMark(
                angle: .value("Monto", segmento.monto),
                innerRadius: .ratio(0.64),
                outerRadius: seleccion == segmento.id
                    ? .ratio(1.05)
                    : .ratio(0.92),
                angularInset: 2
            )
            .cornerRadius(8)
            .foregroundStyle(segmento.color.gradient)
            .opacity(seleccion == nil || seleccion == segmento.id ? 1 : 0.3)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $anguloSeleccionado)
        .frame(height: altura)
        .overlay { centro }
        .animation(.snappy(duration: 0.35), value: seleccion)
        .onChange(of: anguloSeleccionado) { _, nuevo in
            guard let nuevo else { return }
            let tocado = segmento(paraAngulo: nuevo)?.id
            seleccion = seleccion == tocado ? nil : tocado
            Haptics.seleccion()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gastos del mes por categoría")
        .accessibilityValue(descripcionAccesible)
    }

    // MARK: - Centro de la dona

    private var centro: some View {
        VStack(spacing: 4) {
            Text(segmentoSeleccionado?.nombre ?? tituloCentro)
                .font(compacto ? .caption2 : .subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(Formatters.moneda(valorMostrado, moneda: moneda))
                .lineLimit(1)
                // "US$ 13.016,86" no entra en el hueco del donut chico:
                // se achica en vez de pisar el aro.
                .minimumScaleFactor(0.6)
                .font(compacto ? .caption.bold() : .title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .foregroundStyle(segmentoSeleccionado?.color ?? .primary)
        }
        .padding(.horizontal, compacto ? 22 : 40)
        .animation(.snappy(duration: 0.35), value: valorMostrado)
    }

    private var segmentoSeleccionado: SegmentoDonut? {
        guard let seleccion else { return nil }
        return segmentos.first { $0.id == seleccion }
    }

    private var valorMostrado: Double {
        segmentoSeleccionado?.monto ?? valorCentro
    }

    // MARK: - Selección por ángulo

    /// `chartAngleSelection` entrega un valor acumulado dentro del total:
    /// se recorre cada segmento hasta encontrar al que pertenece.
    private func segmento(paraAngulo angulo: Double) -> SegmentoDonut? {
        var acumulado = 0.0
        for segmento in segmentos {
            acumulado += segmento.monto
            if angulo <= acumulado { return segmento }
        }
        return nil
    }

    private var descripcionAccesible: String {
        segmentos
            .map { "\($0.nombre): \(Formatters.moneda($0.monto, moneda: moneda))" }
            .joined(separator: ", ")
    }
}
