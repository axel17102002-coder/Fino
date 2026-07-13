import SwiftUI
import SwiftData

/// Formulario para sumar un monto al progreso de un objetivo de ahorro.
struct AportarObjetivoSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @Query(sort: \ObjetivoAhorro.creado) private var objetivos: [ObjetivoAhorro]

    @State private var objetivoSeleccionado: ObjetivoAhorro?
    @State private var montoTexto = ""

    private var objetivo: ObjetivoAhorro? {
        objetivoSeleccionado ?? objetivos.first
    }

    private var moneda: Moneda {
        objetivo?.moneda ?? .ars
    }

    private var monto: Double? {
        Formatters.parsearMonto(montoTexto)
    }

    private var esValido: Bool {
        objetivo != nil && (monto ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Group {
                if objetivos.isEmpty {
                    EmptyState(
                        icono: "target",
                        titulo: String(localized: "Sin objetivos"),
                        mensaje: String(localized: "Creá un objetivo de ahorro para poder registrar aportes."),
                        tituloAccion: String(localized: "Crear objetivo")
                    ) {
                        dismiss()
                    }
                } else {
                    formulario
                }
            }
            .navigationTitle("Aportar a meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                if !objetivos.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Agregar") { guardar() }
                            .fontWeight(.semibold)
                            .disabled(!esValido)
                    }
                }
            }
            .onAppear {
                if objetivoSeleccionado == nil {
                    objetivoSeleccionado = objetivos.first
                }
            }
        }
    }

    private var formulario: some View {
        Form {
            Section("Objetivo") {
                Picker("Meta", selection: $objetivoSeleccionado) {
                    ForEach(objetivos) { objetivo in
                        Label {
                            Text(objetivo.nombre)
                        } icon: {
                            Image(systemName: objetivo.icono)
                                .foregroundStyle(objetivo.color)
                        }
                        .tag(Optional(objetivo))
                    }
                }

                if let objetivo {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(objetivo.ahorradoFormateado)
                                .font(.headline.monospacedDigit())
                            Spacer()
                            Text("de \(objetivo.metaFormateada)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: objetivo.progreso)
                            .tint(objetivo.color)
                        if objetivo.completado {
                            Label("Meta alcanzada", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("Faltan \(Formatters.moneda(objetivo.restante, moneda: objetivo.moneda))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Monto a agregar") {
                HStack {
                    Text(moneda.simbolo)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $montoTexto)
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                }

                if let monto, monto > 0, let objetivo {
                    LabeledContent("Nuevo total") {
                        Text(Formatters.moneda(objetivo.ahorrado + monto, moneda: objetivo.moneda))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func guardar() {
        guard let objetivo, let monto, monto > 0 else { return }
        objetivo.ahorrado += monto
        try? contexto.save()
        Haptics.exito()
        dismiss()
    }
}

#Preview {
    AportarObjetivoSheet()
        .modelContainer(for: ObjetivoAhorro.self, inMemory: true)
}
