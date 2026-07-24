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

    /// Página del carrusel: 0 = gráficos, 1 = Top categorías + Insights.
    @State private var paginaCarrusel: Int? = 0

    /// Mes que se está mirando en las tarjetas de un solo mes (categorías,
    /// promedios, top categorías). Navegable con el selector de arriba.
    @State private var mesElegido: Date = .now

    /// Se recalcula solo cuando cambian los movimientos o el mes elegido,
    /// no en cada redibujado del `body` (antes era una computed property
    /// que repetía todo el cálculo en cada acceso).
    @State private var viewModel = EstadisticasViewModel(movimientos: [])

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                BarraSuperior("Estadísticas")
                    .foregroundStyle(Color.crema)

                Group {
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
                .laminaRedondeada()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.verdeOscuro.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { actualizarViewModel() }
        .onChange(of: movimientos) { _, _ in actualizarViewModel() }
        .onChange(of: mesElegido) { _, _ in actualizarViewModel() }
    }

    private func actualizarViewModel() {
        viewModel = EstadisticasViewModel(movimientos: movimientos, mes: mesElegido)
    }

    private var contenido: some View {
        ScrollView {
            VStack(spacing: 14) {
                selectorDeMes
                indicadorPaginas
                carrusel
            }
            .padding(.horizontal)
            // Aire arriba para que el selector de mes no quede pegado a la
            // franja verde.
            .padding(.top, 12)
            // Deja pasar el contenido por encima de la barra inferior
            // flotante para que no lo tape al llegar al final.
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Carrusel (gráficos ← → resumen)

    /// Gráficos como página principal; deslizando a la derecha aparecen
    /// Top categorías e Insights. Mismo patrón que el Dashboard.
    private var carrusel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // 32 = margen de pantalla a cada lado: la página siguiente
            // queda fuera de la zona visible en reposo.
            HStack(alignment: .top, spacing: 32) {
                paginaGraficos
                    .containerRelativeFrame(.horizontal)
                    .id(0)
                paginaResumen
                    .containerRelativeFrame(.horizontal)
                    .id(1)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $paginaCarrusel)
        .scrollClipDisabled()
    }

    private var indicadorPaginas: some View {
        HStack(spacing: 7) {
            ForEach(0..<2, id: \.self) { indice in
                Capsule()
                    .fill(.white.opacity(paginaCarrusel == indice ? 0.95 : 0.35))
                    .frame(width: paginaCarrusel == indice ? 18 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.25), value: paginaCarrusel)
    }

    private var paginaGraficos: some View {
        VStack(spacing: 16) {
            tarjetasResumen
            graficoEvolucion
            graficoGastosPorCategoria
            graficoIngresosVsGastos
        }
    }

    private var paginaResumen: some View {
        VStack(spacing: 16) {
            tarjetaTopCategorias
            seccionInsights
            Spacer(minLength: 0)
        }
    }

    // MARK: - Selector de mes

    private var esMesActual: Bool {
        Calendar.current.isDate(mesElegido, equalTo: .now, toGranularity: .month)
    }

    /// Pill centrado con el mes y las flechas como botones circulares, para
    /// que se lea como un control y no como texto suelto sobre la costura.
    private var selectorDeMes: some View {
        HStack(spacing: 10) {
            flechaMes(sistema: "chevron.left", meses: -1, deshabilitado: false)

            Text(mesElegido.mesYAnio)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: mesElegido)
                .frame(minWidth: 130)

            flechaMes(sistema: "chevron.right", meses: 1, deshabilitado: esMesActual)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color.fondoTarjeta))
        .frame(maxWidth: .infinity)
    }

    private func flechaMes(sistema: String, meses: Int, deshabilitado: Bool) -> some View {
        Button {
            mesElegido = mesElegido.agregandoMeses(meses)
        } label: {
            Image(systemName: sistema)
                .font(.footnote.weight(.bold))
                .foregroundStyle(deshabilitado ? .secondary : .primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.rellenoTerciario))
        }
        .disabled(deshabilitado)
    }

    // MARK: - Indicadores

    /// Dos tarjetas lado a lado; cada una agrupa dos métricas apiladas.
    /// Izquierda: promedios diarios. Derecha: mayor gasto y movimientos.
    private var tarjetasResumen: some View {
        HStack(spacing: 14) {
            tarjetaMetricas {
                contenidoIndicador(
                    titulo: String(localized: "Gasto promedio/día"),
                    valor: viewModel.promedioDiarioGastos.enMoneda,
                    icono: "arrow.up.right",
                    color: .red
                )
                Divider()
                contenidoIndicador(
                    titulo: String(localized: "Ingreso promedio/día"),
                    valor: viewModel.promedioDiarioIngresos.enMoneda,
                    icono: "arrow.down.left",
                    color: .green
                )
            }
            tarjetaMetricas {
                contenidoIndicador(
                    titulo: String(localized: "Mayor gasto en"),
                    valor: viewModel.categoriaTopGasto?.categoria.nombre ?? "—",
                    icono: viewModel.categoriaTopGasto?.categoria.icono ?? "questionmark",
                    color: viewModel.categoriaTopGasto?.categoria.color ?? .gray
                )
                Divider()
                contenidoIndicador(
                    titulo: String(localized: "Movimientos"),
                    valor: "\(viewModel.totalMovimientos)",
                    icono: "list.bullet",
                    color: .indigo
                )
            }
        }
    }

    /// Tarjeta media con dos métricas apiladas separadas por una línea fina.
    private func tarjetaMetricas<Contenido: View>(
        @ViewBuilder contenido: () -> Contenido
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            contenido()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .estiloTarjeta(padding: 12)
    }

    private func contenidoIndicador(titulo: String, valor: String, icono: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Ícono y título en la misma línea: la métrica ocupa dos
            // renglones en vez de tres, y la tarjeta queda más cuadrada.
            HStack(spacing: 7) {
                Image(systemName: icono)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(color.opacity(0.15)))
                Text(titulo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(valor)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Gráficos

    private var graficoGastosPorCategoria: some View {
        let items = viewModel.gastosPorCategoria
        let maximo = items.map(\.total).max() ?? 0

        return StatisticsCard(titulo: String(localized: "Gastos por categoría"), subtitulo: mesElegido.mesYAnio) {
            if items.isEmpty {
                sinDatos
            } else {
                Chart(items) { item in
                    // Barras muy largas no dejan lugar para el monto afuera:
                    // en ese caso el número se dibuja adentro, en blanco.
                    let montoAdentro = maximo > 0 && item.total / maximo > 0.6

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
                        position: montoAdentro ? .overlay : .trailing,
                        alignment: montoAdentro ? .trailing : .center,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        if categoriaTocada == item.categoria.nombre {
                            Text(item.total.enMoneda)
                                .font(.caption2.bold())
                                .monospacedDigit()
                                .foregroundStyle(montoAdentro ? .white : item.categoria.color)
                                .padding(.trailing, montoAdentro ? 8 : 0)
                        }
                    }
                }
                .chartYSelection(value: $categoriaTocada)
                .chartXAxis { ejeMonetario }
                .frame(height: CGFloat(items.count) * 34 + 30)
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
                        //.foregroundStyle(Color.crema)
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
                    //.foregroundStyle(Color.crema)
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
