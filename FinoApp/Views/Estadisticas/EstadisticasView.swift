import SwiftUI
import SwiftData
import Charts

/// Serie que se muestra en el gráfico de evolución unificado.
enum SerieEvolucion: String, CaseIterable, Identifiable {
    case gastos, ingresos, balance, cashback

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .gastos: String(localized: "Gastos")
        case .ingresos: String(localized: "Ingresos")
        case .balance: String(localized: "Balance")
        case .cashback: String(localized: "Cashback")
        }
    }

    var color: Color {
        switch self {
        case .gastos: .red
        case .ingresos: .green
        case .balance: .indigo
        case .cashback: .orange
        }
    }

    func valor(de punto: PuntoMensual) -> Double {
        switch self {
        case .gastos: punto.gastos
        case .ingresos: punto.ingresos
        case .balance: punto.balance
        case .cashback: punto.cashback
        }
    }
}

/// Gráficos e insights: evolución unificada con selector de serie,
/// categorías, ingresos vs gastos, top categorías e insights.
struct EstadisticasView: View {

    @Query(sort: \Movimiento.fecha) private var movimientos: [Movimiento]

    @State private var serieSeleccionada: SerieEvolucion = .gastos
    @State private var mesSeleccionado: Date?
    @State private var mesComparado: Date?
    @State private var categoriaTocada: String?

    private var viewModel: EstadisticasViewModel {
        EstadisticasViewModel(movimientos: movimientos)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Título propio en blanco: el título grande del sistema
                // toma el color del tema y se pierde sobre el fondo verde.
                Text("Estadísticas")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                if viewModel.hayDatos {
                    contenido
                } else {
                    EmptyState(
                        icono: "chart.bar.xaxis",
                        titulo: String(localized: "Sin estadísticas"),
                        mensaje: String(localized: "Cuando registres movimientos vas a ver acá tus gráficos e insights.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.fondoPantalla)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var contenido: some View {
        ScrollView {
            VStack(spacing: 16) {
                graficoEvolucion
                indicadoresRapidos
                graficoGastosPorCategoria
                graficoIngresosVsGastos
                tarjetaTopCategorias
                seccionInsights
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Indicadores

    private var indicadoresRapidos: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
            indicador(
                titulo: String(localized: "Gasto promedio/día"),
                valor: viewModel.promedioDiarioGastos.enMoneda,
                icono: "arrow.up.right",
                color: .red
            )
            indicador(
                titulo: String(localized: "Ingreso promedio/día"),
                valor: viewModel.promedioDiarioIngresos.enMoneda,
                icono: "arrow.down.left",
                color: .green
            )
            indicador(
                titulo: String(localized: "Mayor gasto en"),
                valor: viewModel.categoriaTopGasto?.categoria.nombre ?? "—",
                icono: viewModel.categoriaTopGasto?.categoria.icono ?? "questionmark",
                color: viewModel.categoriaTopGasto?.categoria.color ?? .gray
            )
            indicador(
                titulo: String(localized: "Movimientos"),
                valor: "\(viewModel.totalMovimientos)",
                icono: "list.bullet",
                color: .indigo
            )
        }
    }

    private func indicador(titulo: String, valor: String, icono: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icono)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.opacity(0.15)))
            Text(titulo)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(valor)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .estiloTarjeta(padding: 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Gráficos

    private var graficoGastosPorCategoria: some View {
        StatisticsCard(titulo: String(localized: "Gastos por categoría"), subtitulo: Date.now.mesYAnio) {
            if viewModel.gastosPorCategoria.isEmpty {
                sinDatos
            } else {
                Chart(viewModel.gastosPorCategoria) { item in
                    BarMark(
                        x: .value("Monto", item.total),
                        y: .value("Categoría", item.categoria.nombre)
                    )
                    .foregroundStyle(item.categoria.color.gradient)
                    .cornerRadius(5)
                    .opacity(
                        categoriaTocada == nil || categoriaTocada == item.categoria.nombre
                            ? 1 : 0.35
                    )
                    .annotation(
                        position: .trailing,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        if categoriaTocada == item.categoria.nombre {
                            Text(item.total.enMoneda)
                                .font(.caption2.bold())
                                .monospacedDigit()
                                .foregroundStyle(item.categoria.color)
                        }
                    }
                }
                .chartYSelection(value: $categoriaTocada)
                .chartXAxis { ejeMonetario }
                .frame(height: CGFloat(viewModel.gastosPorCategoria.count) * 34 + 30)
                .animation(.snappy(duration: 0.2), value: categoriaTocada)
            }
        }
    }

    private var graficoEvolucion: some View {
        StatisticsCard(titulo: String(localized: "Evolución mensual"), subtitulo: String(localized: "Últimos 6 meses")) {
            VStack(spacing: 14) {
                Picker("Serie", selection: $serieSeleccionada) {
                    ForEach(SerieEvolucion.allCases) { serie in
                        Text(serie.nombre).tag(serie)
                    }
                }
                .pickerStyle(.segmented)

                Chart {
                    if serieSeleccionada == .balance {
                        RuleMark(y: .value("Cero", 0))
                            .foregroundStyle(.secondary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }

                    ForEach(viewModel.series) { punto in
                        AreaMark(
                            x: .value("Mes", punto.mes, unit: .month),
                            y: .value("Monto", serieSeleccionada.valor(de: punto))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    serieSeleccionada.color.opacity(0.3),
                                    serieSeleccionada.color.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Mes", punto.mes, unit: .month),
                            y: .value("Monto", serieSeleccionada.valor(de: punto))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(serieSeleccionada.color)
                        .symbol(.circle)
                    }

                    if let punto = punto(cercanoA: mesSeleccionado) {
                        RuleMark(x: .value("Mes", punto.mes, unit: .month))
                            .foregroundStyle(.secondary.opacity(0.35))
                            .annotation(
                                position: .top,
                                spacing: 6,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                            ) {
                                etiquetaValor(
                                    punto.mes.formatted(.dateTime.month(.wide)),
                                    serieSeleccionada.valor(de: punto),
                                    color: serieSeleccionada.color
                                )
                            }
                        PointMark(
                            x: .value("Mes", punto.mes, unit: .month),
                            y: .value("Monto", serieSeleccionada.valor(de: punto))
                        )
                        .foregroundStyle(serieSeleccionada.color)
                        .symbolSize(100)
                    }
                }
                .chartXSelection(value: $mesSeleccionado)
                .chartXAxis { ejeMeses }
                .chartYAxis { ejeMonetario }
                .frame(height: 200)
                .animation(.snappy(duration: 0.3), value: serieSeleccionada)
            }
        }
        .sensoryFeedback(.selection, trigger: serieSeleccionada)
    }

    private var graficoIngresosVsGastos: some View {
        StatisticsCard(titulo: String(localized: "Ingresos vs Gastos"), subtitulo: String(localized: "Últimos 6 meses")) {
            Chart {
                ForEach(viewModel.series) { punto in
                    BarMark(
                        x: .value("Mes", punto.mes, unit: .month),
                        y: .value("Monto", punto.ingresos),
                        width: .fixed(10)
                    )
                    .position(by: .value("Tipo", String(localized: "Ingresos")))
                    .foregroundStyle(by: .value("Tipo", String(localized: "Ingresos")))
                    .cornerRadius(3)

                    BarMark(
                        x: .value("Mes", punto.mes, unit: .month),
                        y: .value("Monto", punto.gastos),
                        width: .fixed(10)
                    )
                    .position(by: .value("Tipo", String(localized: "Gastos")))
                    .foregroundStyle(by: .value("Tipo", String(localized: "Gastos")))
                    .cornerRadius(3)
                }

                if let punto = punto(cercanoA: mesComparado) {
                    RuleMark(x: .value("Mes", punto.mes, unit: .month))
                        .foregroundStyle(.secondary.opacity(0.35))
                        .annotation(
                            position: .top,
                            spacing: 6,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(punto.mes.formatted(.dateTime.month(.wide)))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("Ingresos: \(punto.ingresos.enMonedaCompacta)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.green)
                                Text("Gastos: \(punto.gastos.enMonedaCompacta)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.red)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.fondoTarjeta)
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            )
                        }
                }
            }
            .chartXSelection(value: $mesComparado)
            .chartForegroundStyleScale([String(localized: "Ingresos"): Color.green, String(localized: "Gastos"): Color.red])
            .chartXAxis { ejeMeses }
            .chartYAxis { ejeMonetario }
            .frame(height: 200)
        }
    }

    /// Punto de la serie más cercano a la fecha tocada en un gráfico.
    private func punto(cercanoA fecha: Date?) -> PuntoMensual? {
        guard let fecha else { return nil }
        return viewModel.series.min {
            abs($0.mes.timeIntervalSince(fecha)) < abs($1.mes.timeIntervalSince(fecha))
        }
    }

    /// Cartelito con el valor del punto seleccionado.
    private func etiquetaValor(_ titulo: String, _ valor: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(titulo)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(valor.enMoneda)
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.fondoTarjeta)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }

    /// Top categorías sin tarjeta: la lista respira sobre el fondo,
    /// con separadores ultrafinos, como una tabla tradicional de iOS.
    @ViewBuilder
    private var tarjetaTopCategorias: some View {
        if !viewModel.topCategorias.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top categorías")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Dónde se va la plata este mes")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.bottom, 10)

                VStack(spacing: 0) {
                    ForEach(Array(viewModel.topCategorias.enumerated()), id: \.element.id) { indice, item in
                        HStack(spacing: 12) {
                            Text("\(indice + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(width: 18)
                            Image(systemName: item.categoria.icono)
                                .font(.caption)
                                .foregroundStyle(item.categoria.color)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(item.categoria.color.opacity(0.2)))
                            Text(item.categoria.nombre)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(item.total.enMoneda)
                                .font(.subheadline.bold())
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 10)

                        if indice < viewModel.topCategorias.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.18))
                                .padding(.leading, 60)
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    /// Insights agrupados en una sola tarjeta continua con
    /// separadores ultrafinos entre cada observación.
    @ViewBuilder
    private var seccionInsights: some View {
        if !viewModel.insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Insights")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    ForEach(Array(viewModel.insights.enumerated()), id: \.element.id) { indice, insight in
                        InsightCard(insight: insight)
                            .padding(.vertical, 10)

                        if indice < viewModel.insights.count - 1 {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
                .estiloTarjeta(padding: 14)
            }
        }
    }

    // MARK: - Ejes y helpers

    private var ejeMeses: some AxisContent {
        AxisMarks(values: .stride(by: .month)) { _ in
            AxisValueLabel(format: .dateTime.month(.abbreviated))
        }
    }

    private var ejeMonetario: some AxisContent {
        AxisMarks { valor in
            AxisGridLine()
            AxisValueLabel {
                if let monto = valor.as(Double.self) {
                    Text(monto.enMonedaCompacta)
                        .font(.caption2)
                }
            }
        }
    }

    private var sinDatos: some View {
        Text("Sin datos este mes")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }
}

#Preview {
    EstadisticasView()
        .modelContainer(for: [Movimiento.self, Cuenta.self], inMemory: true)
}
