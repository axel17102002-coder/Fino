import SwiftUI
import SwiftData

/// Lo que te deben por gastos compartidos, agrupado por persona.
struct DeudasView: View {

    @Query(sort: \Deuda.fecha, order: .reverse) private var deudas: [Deuda]
    @Environment(\.modelContext) private var contexto

    @State private var deudaASaldar: Deuda?

    private var pendientes: [Deuda] { deudas.filter { !$0.saldada } }
    private var saldadas: [Deuda] { deudas.filter(\.saldada) }
    private var totalPendiente: Double { pendientes.reduce(0) { $0 + $1.monto } }

    /// Pendientes agrupadas por persona, la que más debe primero.
    private var porPersona: [(persona: String, deudas: [Deuda], total: Double)] {
        Dictionary(grouping: pendientes, by: \.persona)
            .map { (persona: $0.key, deudas: $0.value, total: $0.value.reduce(0) { $0 + $1.monto }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        Group {
            if deudas.isEmpty {
                EmptyState(
                    icono: "person.2.fill",
                    titulo: String(localized: "Nadie te debe nada"),
                    mensaje: String(localized: "Cuando cargues un gasto, marcalo como compartido y Fino divide la cuenta y se acuerda por vos.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !pendientes.isEmpty {
                        Section {
                            LabeledContent {
                                Text(totalPendiente.enMoneda)
                                    .font(.title3.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(.green)
                            } label: {
                                Text("Te deben en total")
                                    .font(.subheadline)
                            }
                        }
                    }

                    ForEach(porPersona, id: \.persona) { grupo in
                        Section {
                            ForEach(grupo.deudas) { deuda in
                                fila(deuda)
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            deudaASaldar = deuda
                                        } label: {
                                            Label("Saldar", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)
                                    }
                            }
                        } header: {
                            HStack {
                                Text(grupo.persona)
                                Spacer()
                                Text(grupo.total.enMonedaCompacta)
                                    .monospacedDigit()
                            }
                        }
                    }

                    if !saldadas.isEmpty {
                        Section("Saldadas") {
                            ForEach(saldadas) { deuda in
                                fila(deuda)
                                    .foregroundStyle(.secondary)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            contexto.delete(deuda)
                                            try? contexto.save()
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                // Deja pasar el último renglón por encima de la barra inferior.
                .contentMargins(.bottom, 84, for: .scrollContent)
            }
        }
        .background(Color.fondoPantalla)
        .navigationTitle("Me deben")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog(
            "¿Registrar la devolución como ingreso?",
            isPresented: Binding(
                get: { deudaASaldar != nil },
                set: { if !$0 { deudaASaldar = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Sí, sumar el ingreso") {
                if let deuda = deudaASaldar {
                    DeudasService.saldar(deuda, registrandoIngreso: true, en: contexto)
                    Haptics.exito()
                }
                deudaASaldar = nil
            }
            Button("Solo marcar como saldada") {
                if let deuda = deudaASaldar {
                    DeudasService.saldar(deuda, registrandoIngreso: false, en: contexto)
                    Haptics.exito()
                }
                deudaASaldar = nil
            }
            Button("Cancelar", role: .cancel) { deudaASaldar = nil }
        } message: {
            if let deuda = deudaASaldar {
                Text("\(deuda.persona) te devuelve \(deuda.monto.enMoneda). Si lo sumás como ingreso, tu balance del mes lo refleja.")
            }
        }
    }

    private func fila(_ deuda: Deuda) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(deuda.detalle)
                    .font(.subheadline.weight(.medium))
                Text(deuda.fecha.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(deuda.monto.enMonedaCompacta)
                .font(.callout.bold())
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        DeudasView()
    }
    .modelContainer(for: [Deuda.self, Movimiento.self], inMemory: true)
}
