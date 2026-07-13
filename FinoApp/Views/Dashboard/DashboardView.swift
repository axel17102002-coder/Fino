import SwiftUI
import SwiftData

/// Pantalla principal: resumen, análisis del mes, tarjetas, presupuestos y objetivos.
struct DashboardView: View {

    @Query(sort: \Movimiento.fecha, order: .reverse) private var movimientos: [Movimiento]
    @Query(sort: [SortDescriptor(\Cuenta.orden), SortDescriptor(\Cuenta.nombre)]) private var cuentas: [Cuenta]
    @Query private var presupuestos: [Presupuesto]
    @Query(sort: \ObjetivoAhorro.creado) private var objetivos: [ObjetivoAhorro]

    @State private var categoriaSeleccionada: String?
    @State private var mostrandoAlta = false
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
                        seccionTarjetas
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color.fondoPantalla)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $mostrandoAlta) {
                AddTransactionSheet()
            }
        }
    }

    /// Franja verdeOscuro fija en el borde superior: cubre también el
    /// área del reloj/notch y sostiene el logo.
    private var franjaLogo: some View {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 55)
                .offset(y:-10)
                .frame(maxWidth: .infinity, alignment: .leading)
                //.padding(.horizontal)
                //.padding(.bottom, 4)
                .background(Color.verdeOscuro.ignoresSafeArea(edges: .top))
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
                .foregroundStyle(item.categoria.color)
                .frame(width: 30, height: 30)
                .background(Circle().fill(item.categoria.color.opacity(0.14)))

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
                                .fill(item.categoria.color.gradient)
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
                            CuentaResumenCard(cuenta: cuenta)
                        }
                    }
                }
            }
            if !tarjetas.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    encabezado(String(localized: "Tarjetas")) { CuentasView() }
                    filaHorizontal {
                        ForEach(tarjetas) { tarjeta in
                            TarjetaCreditoCard(cuenta: tarjeta)
                        }
                    }
                }
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
