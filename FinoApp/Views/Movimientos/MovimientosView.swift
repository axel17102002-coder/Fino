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

    private var filtrados: [Movimiento] {
        viewModel.aplicar(a: movimientos)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Título propio en blanco: el título grande del sistema
                // toma el color del tema y se pierde sobre el fondo verde.
                HStack {
                    Text("Movimientos")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Spacer()
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
                .padding(.horizontal)
                .padding(.top, 8)

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
            .background(Color.fondoPantalla)
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
                ForEach(filtrados) { movimiento in
                    TransactionRow(movimiento: movimiento)
                        .contentShape(Rectangle())
                        .onTapGesture { movimientoEnEdicion = movimiento }
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
            } header: {
                HStack {
                    // El plural (movimiento/movimientos) lo resuelve el
                    // catálogo de traducciones según el número y el idioma.
                    Text("\(filtrados.count) movimientos")
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if viewModel.hayFiltrosActivos {
                        Button("Limpiar filtros") {
                            viewModel.limpiarFiltros()
                            Haptics.impacto()
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                    }
                }
            } footer: {
                if filtrados.isEmpty {
                    EmptyState(
                        icono: "magnifyingglass",
                        titulo: String(localized: "Sin resultados"),
                        mensaje: String(localized: "Probá con otra búsqueda o limpiá los filtros.")
                    )
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

    // MARK: - Acciones

    private func eliminar(_ movimiento: Movimiento) {
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

#Preview {
    MovimientosView()
        .modelContainer(for: [Movimiento.self, Cuenta.self], inMemory: true)
}
