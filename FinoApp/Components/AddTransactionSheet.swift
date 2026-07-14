import SwiftUI
import SwiftData
import PhotosUI

/// Formulario de alta y edición de movimientos.
struct AddTransactionSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @Query(sort: [SortDescriptor(\Cuenta.orden), SortDescriptor(\Cuenta.nombre)]) private var cuentas: [Cuenta]

    @State private var viewModel: MovimientoFormViewModel
    @State private var categoriasPersonalizadas: [CategoriaPersonalizada] = []
    @State private var mostrandoNuevaCategoria = false

    // Escaneo de tickets.
    @State private var mostrandoEscaner = false
    @State private var fotoTicket: PhotosPickerItem?
    @State private var analizandoTicket = false
    @State private var falloTicket = false

    private let esEdicion: Bool

    init(movimiento: Movimiento? = nil) {
        _viewModel = State(initialValue: MovimientoFormViewModel(movimiento: movimiento))
        esEdicion = movimiento != nil
    }

    private var categoriasDisponibles: [any CategoriaInfo] {
        // `categoriasPersonalizadas` fuerza el refresco al crear una nueva.
        _ = categoriasPersonalizadas
        return CustomCategoryStore.categoriasOrdenadas(para: viewModel.tipo)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $viewModel.tipo) {
                        ForEach(TipoMovimiento.allCases) { tipo in
                            Text(tipo.nombre).tag(tipo)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !esEdicion {
                    Section {
                        if EscanerTicketView.disponible {
                            Button {
                                mostrandoEscaner = true
                            } label: {
                                Label("Escanear ticket", systemImage: "doc.text.viewfinder")
                            }
                        }
                        PhotosPicker(selection: $fotoTicket, matching: .images) {
                            Label("Leer ticket de una foto", systemImage: "photo.on.rectangle")
                        }
                    } footer: {
                        Text("Lee el total, el comercio y la fecha directo del ticket. Todo pasa en tu teléfono.")
                    }
                }

                Section("Datos") {
                    TextField("Nombre", text: $viewModel.nombre)

                    HStack {
                        Text(Formatters.monedaActual.simbolo)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $viewModel.montoTexto)
                            .keyboardType(.decimalPad)
                            .monospacedDigit()
                    }

                    DatePicker("Fecha", selection: $viewModel.fecha, displayedComponents: .date)

                    Picker("Cuenta", selection: $viewModel.cuenta) {
                        Text("Sin cuenta").tag(Cuenta?.none)
                        ForEach(cuentas) { cuenta in
                            Label(cuenta.nombre, systemImage: cuenta.icono)
                                .tag(Cuenta?.some(cuenta))
                        }
                    }

                    if viewModel.permiteCuotas {
                        Stepper(value: $viewModel.cuotas, in: 1...36) {
                            Text(viewModel.cuotas == 1 ? "Pago único" : "\(viewModel.cuotas) cuotas")
                        }
                        if viewModel.cuotas > 1, let monto = viewModel.monto {
                            LabeledContent(
                                "Valor de la cuota",
                                value: (monto / Double(viewModel.cuotas)).enMoneda
                            )
                            .font(.subheadline)
                        }
                    }
                }

                Section("Categoría") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        ForEach(categoriasDisponibles.map(CategoriaEnvuelta.init)) { item in
                            Button {
                                viewModel.categoriaRaw = item.base.rawValue
                                Haptics.seleccion()
                            } label: {
                                CategoryChip(
                                    categoria: item.base,
                                    seleccionada: viewModel.categoriaRaw == item.base.rawValue
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        mostrandoNuevaCategoria = true
                    } label: {
                        Label("Agregar categoría", systemImage: "plus.circle.fill")
                    }
                }

                Section("Notas") {
                    TextField("Notas (opcional)", text: $viewModel.notas, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(viewModel.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if viewModel.guardar(en: contexto) {
                            NotificacionesService.verificarPresupuestos(en: contexto)
                            Haptics.exito()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.esValido)
                }
            }
            .onAppear {
                recargarCategoriasPersonalizadas()
            }
            .onChange(of: viewModel.tipo) { _, _ in
                recargarCategoriasPersonalizadas()
            }
            .sheet(isPresented: $mostrandoNuevaCategoria) {
                // Mismo formulario completo que el editor de Configuración
                // (grilla de íconos y paleta de colores compartida).
                CategoriaFormSheet(existente: nil, tipoInicial: viewModel.tipo) { categoria in
                    recargarCategoriasPersonalizadas()
                    if categoria.tipoRaw == viewModel.tipo.rawValue {
                        viewModel.categoriaRaw = categoria.rawValue
                    }
                }
            }
            .fullScreenCover(isPresented: $mostrandoEscaner) {
                EscanerTicketView { imagen in
                    mostrandoEscaner = false
                    if let imagen {
                        Task { await analizarTicket(imagen) }
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: fotoTicket) { _, item in
                guard let item else { return }
                analizandoTicket = true
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let imagen = UIImage(data: data) {
                        await analizarTicket(imagen)
                    } else {
                        analizandoTicket = false
                        falloTicket = true
                    }
                    fotoTicket = nil
                }
            }
            .overlay {
                if analizandoTicket {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        ProgressView("Leyendo ticket…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .alert("No pude leer el ticket", isPresented: $falloTicket) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Probá de nuevo con más luz o con el ticket más plano. También podés cargar el gasto a mano.")
            }
        }
    }

    /// Corre el OCR y precarga el formulario con lo que se pudo leer.
    private func analizarTicket(_ imagen: UIImage) async {
        analizandoTicket = true
        let datos = await TicketScannerService.analizar(imagen)
        analizandoTicket = false

        guard !datos.estaVacio else {
            falloTicket = true
            return
        }
        if let monto = datos.monto {
            viewModel.montoTexto = monto.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(monto))
                : String(monto)
        }
        if let nombre = datos.nombre {
            viewModel.nombre = nombre
        }
        if let fecha = datos.fecha {
            viewModel.fecha = fecha
        }
        Haptics.exito()
    }

    private func recargarCategoriasPersonalizadas() {
        categoriasPersonalizadas = CustomCategoryStore.categorias(para: viewModel.tipo)
    }
}

#Preview {
    AddTransactionSheet()
        .modelContainer(for: [Movimiento.self, Cuenta.self], inMemory: true)
}
