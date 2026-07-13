import SwiftUI

/// Sheet de filtros y orden para la pantalla de Movimientos.
struct FilterSheet: View {

    @Bindable var viewModel: MovimientosViewModel
    let mesesDisponibles: [Date]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $viewModel.tipo) {
                        Text("Todos").tag(TipoMovimiento?.none)
                        ForEach(TipoMovimiento.allCases) { tipo in
                            Text(tipo.nombrePlural).tag(TipoMovimiento?.some(tipo))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Mes") {
                    Picker("Mes", selection: $viewModel.mes) {
                        Text("Todos").tag(Date?.none)
                        ForEach(mesesDisponibles, id: \.self) { mes in
                            Text(mes.mesYAnio).tag(Date?.some(mes))
                        }
                    }
                }

                Section("Categoría") {
                    Picker("Categoría", selection: $viewModel.categoriaRaw) {
                        Text("Todas").tag(String?.none)
                        ForEach(viewModel.categoriasParaFiltro.map(CategoriaEnvuelta.init)) { item in
                            Label(item.base.nombre, systemImage: item.base.icono)
                                .tag(String?.some(item.base.rawValue))
                        }
                    }
                }

                Section("Ordenar por") {
                    Picker("Orden", selection: $viewModel.orden) {
                        ForEach(OrdenMovimientos.allCases) { orden in
                            Text(orden.nombre).tag(orden)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if viewModel.hayFiltrosActivos {
                    Button("Limpiar filtros", role: .destructive) {
                        viewModel.limpiarFiltros()
                        Haptics.impacto()
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
