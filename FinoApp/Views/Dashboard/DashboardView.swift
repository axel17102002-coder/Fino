import SwiftUI
import SwiftData

/// Pantalla principal: resumen, análisis del mes, tarjetas, presupuestos y objetivos.
struct DashboardView: View {

    @Query(sort: \Movimiento.fecha, order: .reverse) private var movimientos: [Movimiento]
    @Query(sort: [SortDescriptor(\Cuenta.orden), SortDescriptor(\Cuenta.nombre)]) private var cuentas: [Cuenta]
    @Query private var presupuestos: [Presupuesto]
    @Query(sort: \ObjetivoAhorro.creado) private var objetivos: [ObjetivoAhorro]
    @Query(filter: #Predicate<Deuda> { !$0.saldada }) private var deudasPendientes: [Deuda]

    @State private var categoriaSeleccionada: String?
    @State private var mostrandoAlta = false
    @State private var mostrandoEscanerTicket = false
    @State private var paginaCarrusel: Int? = 0

    private var viewModel: DashboardViewModel {
        DashboardViewModel(movimientos: movimientos)
    }

    private var tarjetas: [Cuenta] {
        cuentas.filter(\.esTarjetaCredito)
    }

    private var categoriasConMasConsumo: [TotalCategoria] {
        CalculosService
            .totalesPorCategoria(viewModel.movimientosDelMes, tipo: .gasto)
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                franjaLogo
                ScrollView {
                    VStack(spacing: 25) {
                        DashboardHeader()
                        carruselPrincipal
                        bannerDeudas
                        seccionTarjetas
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                // El contenido es una "lámina" con las esquinas de arriba
                // redondeadas que se monta sobre el verde de la franja.
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
                        .fill(Color.fondoPantalla)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
            .background(Color.verdeOscuro.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $mostrandoAlta) {
                AddTransactionSheet()
            }
            .sheet(isPresented: $mostrandoEscanerTicket) {
                AddTransactionSheet(escanearAlAbrir: true)
            }
        }
    }

    /// Franja verdeOscuro fija en el borde superior: cubre el área del
    /// reloj/notch, sostiene el logo y el ojito de privacidad.
    private var franjaLogo: some View {
        HStack(alignment: .center) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 106, height: 44)
                //.padding(.bottom, 5)

            Spacer()

            // Atajo al escáner de tickets: la vía más rápida de cargar
            // un gasto real.
            Button {
                mostrandoEscanerTicket = true
                Haptics.seleccion()
            } label: {
                Image(systemName: "doc.text.viewfinder")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.verdeOscuro)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.crema))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Escanear ticket"))
        }
        .padding(.leading, 5)
        .padding(.trailing)
        .padding(.bottom, 11)
        .padding(.top, -3)
        .frame(maxWidth: .infinity)
        .frame(height: 45)
        .background(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 24,
                    bottomTrailingRadius: 24
                )
                .fill(Color.verdeOscuro)
                .ignoresSafeArea(edges: .top)
            )
    }

    /// Acceso rápido a "Me deben" cuando hay deudas pendientes.
    @ViewBuilder
    private var bannerDeudas: some View {
        if !deudasPendientes.isEmpty {
            NavigationLink {
                DeudasView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.green.legible())
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.green.legible().opacity(0.18)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Te deben")
                            .font(.subheadline.weight(.semibold))
                        Text("^[\(deudasPendientes.count) deuda](inflect: true) pendiente")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(deudasPendientes.reduce(0) { $0 + $1.monto }.enMoneda)
                        .font(.callout.bold())
                        .monospacedDigit()
                        .foregroundStyle(Color.green.legible())
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .estiloTarjeta(padding: 14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Carrusel principal

    /// Resumen, presupuestos y objetivos como páginas deslizables.
    private var carruselPrincipal: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                // 32 = margen de pantalla a cada lado (16+16): la página
                // siguiente queda fuera de la zona visible en reposo, sin
                // necesidad de recortar el scroll.
                HStack(alignment: .top, spacing: 32) {
                    seccionResumenYAnalisis
                        .containerRelativeFrame(.horizontal)
                        .id(0)
                    paginaPresupuestos
                        .containerRelativeFrame(.horizontal)
                        .id(1)
                    paginaObjetivos
                        .containerRelativeFrame(.horizontal)
                        .id(2)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $paginaCarrusel)
            .scrollClipDisabled()

            indicadorPaginas
        }
    }

    private var indicadorPaginas: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { indice in
                Capsule()
                    .fill(.white.opacity(paginaCarrusel == indice ? 0.95 : 0.35))
                    .frame(width: paginaCarrusel == indice ? 18 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.25), value: paginaCarrusel)
    }

    // MARK: - Secciones

    private var seccionResumenYAnalisis: some View {
        VStack(alignment: .leading, spacing: 18) {
            BalanceCard(
                balance: viewModel.balance,
                ingresos: viewModel.totalIngresos,
                gastos: viewModel.totalGastos,
                cashback: viewModel.totalCashback,
                ultimosMovimientos: viewModel.ultimosMovimientos
            )

            Divider()

            if viewModel.hayDatosEnElMes {
                analisisDelMes
            } else {
                EmptyState(
                    icono: "chart.pie",
                    titulo: String(localized: "Sin datos este mes"),
                    mensaje: String(localized: "Agregá tu primer movimiento para ver el resumen del mes."),
                    tituloAccion: String(localized: "Agregar movimiento")
                ) {
                    mostrandoAlta = true
                }
            }
        }
        .estiloTarjeta(padding: 18)
    }

    private var analisisDelMes: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Análisis del mes")
                    .font(.headline)
                Spacer()
                Text("Top consumos")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 18) {
                    donutCompacto
                        .frame(width: 150)
                    categoriasTop
                }

                VStack(alignment: .leading, spacing: 16) {
                    donutCompacto
                    categoriasTop
                }
            }
        }
    }

    private var donutCompacto: some View {
        DonutChart(
            segmentos: viewModel.segmentosDonut,
            seleccion: $categoriaSeleccionada,
            tituloCentro: String(localized: "Gastos"),
            valorCentro: viewModel.totalGastos,
            altura: 150,
            compacto: true
        )
    }

    @ViewBuilder
    private var categoriasTop: some View {
        if categoriasConMasConsumo.isEmpty {
            Text("Todavía no hay categorías de consumo este mes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 10) {
                ForEach(categoriasConMasConsumo) { item in
                    filaCategoriaTop(item)
                }
            }
        }
    }

    private func filaCategoriaTop(_ item: TotalCategoria) -> some View {
        let totalGastos = max(viewModel.totalGastos, 1)
        let progreso = min(item.total / totalGastos, 1)

        return HStack(spacing: 10) {
            Image(systemName: item.categoria.icono)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.categoria.color.legible())
                .frame(width: 30, height: 30)
                .background(Circle().fill(item.categoria.color.legible().opacity(0.18)))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.categoria.nombre)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(item.total.enMonedaCompacta)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.rellenoTerciario)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(item.categoria.color.legible().gradient)
                                .frame(width: proxy.size.width * progreso)
                        }
                }
                .frame(height: 6)
            }
        }
    }

    private var otrasCuentas: [Cuenta] {
        cuentas.filter { !$0.esTarjetaCredito }
    }

    @ViewBuilder
    private var seccionTarjetas: some View {
        if cuentas.isEmpty {
            accesoVacio(String(localized: "Configurar cuentas y tarjetas"), icono: "creditcard.fill") {
                CuentasView()
            }
        } else {
            if !otrasCuentas.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    encabezado(String(localized: "Cuentas")) { CuentasView() }
                    filaHorizontal {
                        ForEach(otrasCuentas) { cuenta in
                            NavigationLink {
                                CuentaDetalleView(cuenta: cuenta)
                            } label: {
                                CuentaResumenCard(cuenta: cuenta)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if !tarjetas.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    encabezado(String(localized: "Tarjetas")) { CuentasView() }
                    filaHorizontal {
                        ForEach(tarjetas) { tarjeta in
                            NavigationLink {
                                CuentaDetalleView(cuenta: tarjeta)
                            } label: {
                                TarjetaCreditoCard(cuenta: tarjeta)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                // Próximos cierres y vencimientos (solo tarjetas que los
                // tengan configurados).
                VencimientosCard(tarjetas: tarjetas)
            }
        }
    }

    private func filaHorizontal(@ViewBuilder contenido: () -> some View) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                contenido()
            }
            .padding(.vertical, 6)
        }
        .scrollClipDisabled()
    }

    /// Aunque no haya presupuestos, el acceso queda siempre visible
    /// (si no, después de borrar los datos no hay forma de crearlos).
    @ViewBuilder
    private var paginaPresupuestos: some View {
        VStack(alignment: .leading, spacing: 12){
            // El color crema del título lo pone encabezado(): un solo
            // lugar para todos los títulos de sección.
            encabezado(String(localized: "Presupuestos")) { PresupuestosView() }
            if !presupuestos.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(presupuestos.prefix(4))) { presupuesto in
                        PresupuestoRow(
                            presupuesto: presupuesto,
                            gastado: CalculosService.gastado(en: presupuesto.categoria, movimientos: movimientos)
                        )
                    }
                }
                .estiloTarjeta()
            } else {
                accesoVacio(String(localized: "Crear presupuestos"), icono: "chart.pie.fill") {
                    PresupuestosView()
                }
            }
        }
    }

    /// Igual que los presupuestos: el acceso a objetivos nunca desaparece.
    @ViewBuilder
    private var paginaObjetivos: some View {
        VStack(alignment: .leading, spacing: 12) {
            encabezado(String(localized: "Objetivos")) { ObjetivosView() }
            if !objetivos.isEmpty {
                VStack(spacing: 14) {
                    ForEach(Array(objetivos.prefix(3))) { objetivo in
                        filaObjetivo(objetivo)
                    }
                }
                .estiloTarjeta()
            } else {
                accesoVacio(String(localized: "Crear objetivos de ahorro"), icono: "flag.fill") {
                    ObjetivosView()
                }
            }
        }
    }

    /// Versión compacta de `ObjetivoCard` para la página del carrusel:
    /// dentro del pager no puede haber otro scroll horizontal.
    private func filaObjetivo(_ objetivo: ObjetivoAhorro) -> some View {
        HStack(spacing: 10) {
            Image(systemName: objetivo.icono)
                .font(.caption.weight(.semibold))
                .foregroundStyle(objetivo.color)
                .frame(width: 30, height: 30)
                .background(Circle().fill(objetivo.color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(objetivo.nombre)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if objetivo.completado {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Spacer(minLength: 8)
                    Text(objetivo.ahorradoFormateado)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ProgressView(value: objetivo.progreso)
                    .tint(objetivo.color)

                HStack {
                    Text(Formatters.porcentaje(objetivo.progreso))
                        .font(.caption2.bold())
                        .foregroundStyle(objetivo.color)
                    Spacer()
                    Text("Meta \(objetivo.metaFormateadaCompacta)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Tarjeta de acceso para las secciones que todavía no tienen datos.
    private func accesoVacio<Destino: View>(
        _ titulo: String,
        icono: String,
        @ViewBuilder destino: @escaping () -> Destino
    ) -> some View {
        NavigationLink {
            destino()
        } label: {
            HStack {
                Label(titulo, systemImage: icono)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .estiloTarjeta()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func encabezado<Destino: View>(
        _ titulo: String,
        @ViewBuilder destino: @escaping () -> Destino
    ) -> some View {
        HStack {
            Text(titulo)
                .font(.headline)
                .foregroundStyle(Color.crema)
            Spacer()
            NavigationLink {
                destino()
            } label: {
                HStack(spacing: 3) {
                    Text("Ver todo")
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(
            for: [Movimiento.self, Cuenta.self, Presupuesto.self, ObjetivoAhorro.self],
            inMemory: true
        )
}
