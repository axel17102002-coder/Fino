import SwiftUI
import SwiftData

/// Presupuestos mensuales por categoría de gasto.
struct PresupuestosView: View {

    @Query private var presupuestos: [Presupuesto]
    @Query private var movimientos: [Movimiento]
    @Environment(\.modelContext) private var contexto

    @State private var mostrandoAlta = false

    var body: some View {
        Group {
            if presupuestos.isEmpty {
                EmptyState(
                    icono: "chart.bar.doc.horizontal",
                    titulo: String(localized: "Sin presupuestos"),
                    mensaje: String(localized: "Definí un tope mensual por categoría y controlá cuánto llevás gastado."),
                    tituloAccion: String(localized: "Crear presupuesto")
                ) {
                    mostrandoAlta = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(presupuestos.sorted { $0.categoria.nombre < $1.categoria.nombre }) { presupuesto in
                        PresupuestoRow(
                            presupuesto: presupuesto,
                            gastado: CalculosService.gastado(en: presupuesto.categoria, movimientos: movimientos)
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                eliminar(presupuesto)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.fondoPantalla)
        .navigationTitle("Presupuestos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mostrandoAlta = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Agregar presupuesto")
            }
        }
        .sheet(isPresented: $mostrandoAlta) {
            AddPresupuestoSheet()
                .presentationDetents([.medium])
        }
    }

    private func eliminar(_ presupuesto: Presupuesto) {
        contexto.delete(presupuesto)
        try? contexto.save()
        Haptics.advertencia()
    }
}

/// Alta de un presupuesto mensual para una categoría de gasto.
struct AddPresupuestoSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @Query private var presupuestos: [Presupuesto]

    @State private var categoria: CategoriaGasto = .comida
    @State private var montoTexto = ""

    /// Categorías que todavía no tienen presupuesto asignado.
    private var categoriasDisponibles: [CategoriaGasto] {
        let usadas = Set(presupuestos.map(\.categoriaRaw))
        return CategoriaGasto.allCases.filter { !usadas.contains($0.rawValue) }
    }

    private var esValido: Bool {
        (Formatters.parsearMonto(montoTexto) ?? 0) > 0
            && categoriasDisponibles.contains(categoria)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Categoría", selection: $categoria) {
                    ForEach(categoriasDisponibles) { categoria in
                        Label(categoria.nombre, systemImage: categoria.icono).tag(categoria)
                    }
                }
                HStack {
                    Text("Monto mensual")
                    Spacer()
                    TextField("0", text: $montoTexto)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            .navigationTitle("Nuevo presupuesto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .fontWeight(.semibold)
                        .disabled(!esValido)
                }
            }
            .onAppear {
                if let primera = categoriasDisponibles.first {
                    categoria = primera
                }
            }
        }
    }

    private func guardar() {
        guard let monto = Formatters.parsearMonto(montoTexto) else { return }
        contexto.insert(Presupuesto(categoria: categoria, montoMensual: monto))
        try? contexto.save()
        Haptics.exito()
        dismiss()
    }
}
