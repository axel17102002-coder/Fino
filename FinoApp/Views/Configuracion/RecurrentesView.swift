import SwiftUI
import SwiftData

/// Gestión de movimientos recurrentes: suscripciones, alquiler, sueldo, etc.
struct RecurrentesView: View {

    @Query(sort: \MovimientoRecurrente.creado) private var recurrentes: [MovimientoRecurrente]
    @Environment(\.modelContext) private var contexto

    @State private var mostrandoAlta = false
    @State private var recurrenteEnEdicion: MovimientoRecurrente?

    var body: some View {
        Group {
            if recurrentes.isEmpty {
                EmptyState(
                    icono: "arrow.triangle.2.circlepath",
                    titulo: String(localized: "Sin recurrentes"),
                    mensaje: String(localized: "Creá plantillas para suscripciones, alquiler o tu sueldo: se cargan solas todos los meses."),
                    tituloAccion: String(localized: "Crear recurrente")
                ) {
                    mostrandoAlta = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(recurrentes) { recurrente in
                        fila(recurrente)
                            .contentShape(Rectangle())
                            .onTapGesture { recurrenteEnEdicion = recurrente }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    contexto.delete(recurrente)
                                    try? contexto.save()
                                    Haptics.advertencia()
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                Button {
                                    recurrenteEnEdicion = recurrente
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .scrollContentBackground(.hidden)
                // Deja pasar el último renglón por encima de la barra inferior.
                .contentMargins(.bottom, 84, for: .scrollContent)
            }
        }
        .background(Color.fondoPantalla)
        .navigationTitle("Recurrentes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mostrandoAlta = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nuevo recurrente")
            }
        }
        .sheet(isPresented: $mostrandoAlta) {
            RecurrenteFormSheet()
        }
        .sheet(item: $recurrenteEnEdicion) { recurrente in
            RecurrenteFormSheet(existente: recurrente)
        }
    }

    private func fila(_ recurrente: MovimientoRecurrente) -> some View {
        HStack(spacing: 12) {
            Image(systemName: recurrente.categoria?.icono ?? "arrow.triangle.2.circlepath")
                .font(.subheadline)
                .foregroundStyle(recurrente.categoria?.color ?? .gray)
                .frame(width: 34, height: 34)
                .background(Circle().fill((recurrente.categoria?.color ?? .gray).opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(recurrente.nombre)
                    .font(.subheadline.weight(.semibold))
                Text("\(recurrente.tipo.nombre) · todos los meses el día \(recurrente.diaDelMes)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(recurrente.monto.enMonedaCompacta)
                    .font(.callout.bold())
                    .monospacedDigit()
                Toggle("", isOn: Binding(
                    get: { recurrente.activo },
                    set: { valor in
                        recurrente.activo = valor
                        try? contexto.save()
                        Haptics.seleccion()
                    }
                ))
                .labelsHidden()
                .scaleEffect(0.75)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Formulario de alta y edición de una plantilla recurrente.
private struct RecurrenteFormSheet: View {

    /// Plantilla a editar; `nil` para crear una nueva.
    let existente: MovimientoRecurrente?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @Query(sort: [SortDescriptor(\Cuenta.orden), SortDescriptor(\Cuenta.nombre)]) private var cuentas: [Cuenta]

    @State private var tipo: TipoMovimiento
    @State private var nombre: String
    @State private var montoTexto: String
    @State private var categoriaRaw: String
    @State private var diaDelMes: Int
    @State private var cuenta: Cuenta?

    init(existente: MovimientoRecurrente? = nil) {
        self.existente = existente
        _tipo = State(initialValue: existente?.tipo ?? .gasto)
        _nombre = State(initialValue: existente?.nombre ?? "")
        _montoTexto = State(initialValue: existente.map {
            $0.monto.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int($0.monto))
                : String($0.monto)
        } ?? "")
        _categoriaRaw = State(initialValue: existente?.categoriaRaw ?? CategoriaGasto.suscripciones.rawValue)
        _diaDelMes = State(initialValue: existente?.diaDelMes ?? 1)
        _cuenta = State(initialValue: existente?.cuenta)
    }

    private var categoriasDisponibles: [any CategoriaInfo] {
        CustomCategoryStore.categoriasOrdenadas(para: tipo)
    }

    private var esValido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
            && (Formatters.parsearMonto(montoTexto) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $tipo) {
                        ForEach(TipoMovimiento.allCases) { tipo in
                            Text(tipo.nombre).tag(tipo)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: tipo) { _, nuevo in
                        categoriaRaw = nuevo.categoriaPorDefecto.rawValue
                    }
                }

                Section("Datos") {
                    TextField("Nombre (ej: Netflix, Alquiler, Sueldo)", text: $nombre)

                    HStack {
                        Text(Formatters.monedaActual.simbolo)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $montoTexto)
                            .keyboardType(.decimalPad)
                            .monospacedDigit()
                    }

                    Picker("Día del mes", selection: $diaDelMes) {
                        ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                    }

                    Picker("Cuenta", selection: $cuenta) {
                        Text("Sin cuenta").tag(Cuenta?.none)
                        ForEach(cuentas) { cuenta in
                            Label(cuenta.nombre, systemImage: cuenta.icono)
                                .tag(Cuenta?.some(cuenta))
                        }
                    }
                }

                Section("Categoría") {
                    Picker("Categoría", selection: $categoriaRaw) {
                        ForEach(categoriasDisponibles.map(CategoriaEnvuelta.init)) { item in
                            Label(item.base.nombre, systemImage: item.base.icono)
                                .tag(item.base.rawValue)
                        }
                    }
                }
            }
            .navigationTitle(existente == nil ? "Nuevo recurrente" : "Editar recurrente")
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
        }
    }

    private func guardar() {
        guard let monto = Formatters.parsearMonto(montoTexto) else { return }
        if let existente {
            existente.nombre = nombre.trimmingCharacters(in: .whitespaces)
            existente.tipo = tipo
            existente.categoriaRaw = categoriaRaw
            existente.monto = monto
            existente.diaDelMes = diaDelMes
            existente.cuenta = cuenta
        } else {
            contexto.insert(MovimientoRecurrente(
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                tipo: tipo,
                categoriaRaw: categoriaRaw,
                monto: monto,
                diaDelMes: diaDelMes,
                cuenta: cuenta
            ))
        }
        try? contexto.save()
        Haptics.exito()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RecurrentesView()
    }
    .modelContainer(for: [MovimientoRecurrente.self, Cuenta.self, Movimiento.self], inMemory: true)
}
