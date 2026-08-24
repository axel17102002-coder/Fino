import SwiftUI
import SwiftData

/// Listado completo de movimientos con búsqueda, filtros, orden y acciones.
struct MovimientosView: View {

    @Query(sort: \Movimiento.fecha, order: .reverse) private var movimientos: [Movimiento]
    @Environment(\.modelContext) private var contexto

    @State private var viewModel = MovimientosViewModel()
    @State private var mostrandoFiltros = false
    @State private var mostrandoAlta = false
    @State private var movimientoEnEdicion: Movimiento?
    @State private var movimientoConTicket: Movimiento?

    private var filtrados: [Movimiento] {
        viewModel.aplicar(a: movimientos)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BarraSuperior("Movimientos") {
                    Button {
                        mostrandoFiltros = true
                    } label: {
                        Image(systemName: viewModel.hayFiltrosActivos
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Filtros")
                }

                Group {
                    if movimientos.isEmpty {
                        EmptyState(
                            icono: "tray",
                            titulo: String(localized: "Sin movimientos"),
                            mensaje: String(localized: "Registrá tus gastos, ingresos y cashback para empezar."),
                            tituloAccion: String(localized: "Agregar movimiento")
                        ) {
                            mostrandoAlta = true
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        lista
                    }
                }
                .laminaRedondeada()
            }
            .background(Color.verdeOscuro.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $mostrandoFiltros) {
                FilterSheet(
                    viewModel: viewModel,
                    mesesDisponibles: MovimientosViewModel.mesesDisponibles(en: movimientos)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $mostrandoAlta) {
                AddTransactionSheet()
            }
            .sheet(item: $movimientoEnEdicion) { movimiento in
                AddTransactionSheet(movimiento: movimiento)
            }
            .sheet(item: $movimientoConTicket) { movimiento in
                TicketSheet(movimiento: movimiento)
            }
        }
    }

    // MARK: - Lista

    private var lista: some View {
        List {
            Section {
                SearchBar(texto: $viewModel.busqueda, placeholder: String(localized: "Buscar por nombre, categoría o cuenta"))
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                resumenDeLaLista
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(porDia) { dia in
                Section {
                    ForEach(dia.movimientos) { movimiento in
                        fila(movimiento)
                    }
                } header: {
                    encabezado(de: dia)
                }
            }

            if filtrados.isEmpty {
                Section {
                    EmptyState(
                        icono: "magnifyingglass",
                        titulo: String(localized: "Sin resultados"),
                        mensaje: String(localized: "Probá con otra búsqueda o limpiá los filtros.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // Deja pasar el último renglón por encima de la barra inferior.
        .contentMargins(.bottom, 84, for: .scrollContent)
        .scrollDismissesKeyboard(.immediately)
        .animation(.snappy(duration: 0.25), value: filtrados.count)
    }

    // MARK: - Piezas de la lista

    /// Cuántos movimientos se están viendo y el acceso a limpiar filtros.
    private var resumenDeLaLista: some View {
        HStack {
            // El plural (movimiento/movimientos) lo resuelve el catálogo
            // de traducciones según el número y el idioma.
            Text("\(filtrados.count) movimientos")
                .font(.headline)
                .foregroundStyle(Color.crema)
            Spacer()
            if viewModel.hayFiltrosActivos {
                Button("Limpiar filtros") {
                    viewModel.limpiarFiltros()
                    Haptics.impacto()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.crema)
            }
        }
    }

    /// Día y lo gastado ese día. Cuenta la parte propia de los gastos
    /// compartidos, igual que el resto de la app.
    private func encabezado(de dia: DiaDeMovimientos) -> some View {
        HStack {
            Text(dia.titulo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.crema)
            Spacer()
            if let gasto = dia.gastoDelDia {
                Text(gasto.enMoneda)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.crema.opacity(0.7))
            }
        }
        .textCase(nil)
    }

    private func fila(_ movimiento: Movimiento) -> some View {
        // La fecha no se repite en el renglón: está en el encabezado del día.
        TransactionRow(movimiento: movimiento, mostrarFecha: false)
            .filaDeVidrio()
            .contentShape(Rectangle())
            // Si el gasto se cargó escaneando, primero se ve el ticket;
            // editar queda a un botón. Sin detalle no hay nada que
            // mostrar y se abre el formulario.
            .onTapGesture {
                if movimiento.itemsTicket?.isEmpty == false {
                    movimientoConTicket = movimiento
                } else {
                    movimientoEnEdicion = movimiento
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    eliminar(movimiento)
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
                Button {
                    movimientoEnEdicion = movimiento
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .leading) {
                Button {
                    duplicar(movimiento)
                } label: {
                    Label("Duplicar", systemImage: "plus.square.on.square")
                }
                .tint(.indigo)
            }
    }

    // MARK: - Agrupación por día

    /// Los movimientos filtrados, partidos por día y del más nuevo al más
    /// viejo. Dentro de cada día se conserva el orden de la consulta.
    private var porDia: [DiaDeMovimientos] {
        let calendario = Calendar.current
        let agrupados = Dictionary(grouping: filtrados) {
            calendario.startOfDay(for: $0.fecha)
        }
        return agrupados.keys.sorted(by: >).map {
            DiaDeMovimientos(fecha: $0, movimientos: agrupados[$0] ?? [])
        }
    }

    // MARK: - Acciones

    private func eliminar(_ movimiento: Movimiento) {
        // Si era un gasto compartido, sus deudas se van con él.
        DeudasService.eliminarVinculadas(a: movimiento.id, en: contexto)
        contexto.delete(movimiento)
        try? contexto.save()
        Haptics.advertencia()
    }

    private func duplicar(_ movimiento: Movimiento) {
        contexto.insert(movimiento.duplicado())
        try? contexto.save()
        Haptics.exito()
    }
}

/// Un día de la lista: su fecha, sus movimientos y el saldo del día.
private struct DiaDeMovimientos: Identifiable {

    /// Comienzo del día, que además sirve de identidad de la sección.
    let fecha: Date
    let movimientos: [Movimiento]

    var id: Date { fecha }

    /// Lo que salió ese día: los gastos, menos el cashback que los
    /// compensa. Los ingresos quedan afuera a propósito — el encabezado
    /// es para ver cuánto gastaste, y un sueldo daba vuelta el número y
    /// tapaba el gasto del día.
    ///
    /// `nil` cuando el día solo tuvo ingresos: ahí no hay gasto que
    /// mostrar y un "$ 0" confundiría más de lo que aporta.
    var gastoDelDia: Double? {
        let deSalida = movimientos.filter { $0.tipo != .ingreso }
        guard !deSalida.isEmpty else { return nil }
        return deSalida.reduce(0) { $0 + $1.montoPropioConSigno }
    }

    /// "Hoy" y "Ayer" en vez de la fecha, que es como uno los nombra. Los
    /// días de este año no llevan el año; los anteriores sí.
    var titulo: String {
        let calendario = Calendar.current
        if calendario.isDateInToday(fecha) { return String(localized: "Hoy") }
        if calendario.isDateInYesterday(fecha) { return String(localized: "Ayer") }
        if calendario.isDate(fecha, equalTo: .now, toGranularity: .year) {
            return fecha.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
        return fecha.formatted(.dateTime.day().month(.wide).year())
    }
}

#Preview {
    MovimientosView()
        .modelContainer(for: [Movimiento.self, Cuenta.self], inMemory: true)
}
