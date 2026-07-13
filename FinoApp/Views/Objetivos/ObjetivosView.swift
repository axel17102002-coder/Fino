import SwiftUI
import SwiftData

/// Objetivos de ahorro con barra de progreso.
struct ObjetivosView: View {

    @Query(sort: \ObjetivoAhorro.creado) private var objetivos: [ObjetivoAhorro]
    @Environment(\.modelContext) private var contexto

    @State private var mostrandoAlta = false
    @State private var objetivoEnEdicion: ObjetivoAhorro?

    var body: some View {
        Group {
            if objetivos.isEmpty {
                EmptyState(
                    icono: "target",
                    titulo: String(localized: "Sin objetivos"),
                    mensaje: String(localized: "Creá objetivos de ahorro y seguí tu progreso hasta alcanzarlos."),
                    tituloAccion: String(localized: "Crear objetivo")
                ) {
                    mostrandoAlta = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(objetivos) { objetivo in
                        fila(objetivo)
                            .contentShape(Rectangle())
                            .onTapGesture { objetivoEnEdicion = objetivo }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    eliminar(objetivo)
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
        .navigationTitle("Objetivos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mostrandoAlta = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Agregar objetivo")
            }
        }
        .sheet(isPresented: $mostrandoAlta) {
            AddObjetivoSheet()
        }
        .sheet(item: $objetivoEnEdicion) { objetivo in
            AddObjetivoSheet(objetivo: objetivo)
        }
    }

    private func fila(_ objetivo: ObjetivoAhorro) -> some View {
        HStack(spacing: 12) {
            Image(systemName: objetivo.icono)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(objetivo.color)
                .frame(width: 40, height: 40)
                .background(Circle().fill(objetivo.color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(objetivo.nombre)
                        .font(.subheadline.weight(.semibold))
                    if objetivo.completado {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Text(Formatters.porcentaje(objetivo.progreso))
                        .font(.caption.bold())
                        .foregroundStyle(objetivo.color)
                }
                ProgressView(value: objetivo.progreso)
                    .tint(objetivo.color)
                HStack {
                    Text(objetivo.ahorradoFormateado)
                    Spacer()
                    Text("Meta \(objetivo.metaFormateada)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func eliminar(_ objetivo: ObjetivoAhorro) {
        contexto.delete(objetivo)
        try? contexto.save()
        Haptics.advertencia()
    }
}

/// Alta y edición de un objetivo de ahorro.
struct AddObjetivoSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto

    private let objetivoEditado: ObjetivoAhorro?

    @State private var nombre: String
    @State private var metaTexto: String
    @State private var ahorradoTexto: String
    @State private var icono: String
    @State private var colorHex: String
    @State private var monedaRaw: String

    private static let iconos = [
        "beach.umbrella.fill", "airplane", "house.fill", "car.fill",
        "iphone", "graduationcap.fill", "gift.fill", "star.fill"
    ]
    private static let paleta = Paleta.colores

    init(objetivo: ObjetivoAhorro? = nil) {
        objetivoEditado = objetivo
        let moneda = objetivo?.moneda ?? .ars
        _nombre = State(initialValue: objetivo?.nombre ?? "")
        _metaTexto = State(initialValue: objetivo.map { Formatters.montoEditable($0.meta, moneda: $0.moneda) } ?? "")
        _ahorradoTexto = State(initialValue: objetivo.map { Formatters.montoEditable($0.ahorrado, moneda: $0.moneda) } ?? "")
        _icono = State(initialValue: objetivo?.icono ?? "beach.umbrella.fill")
        _colorHex = State(initialValue: objetivo?.colorHex ?? "0EA5E9")
        _monedaRaw = State(initialValue: moneda.rawValue)
    }

    private var moneda: Moneda {
        Moneda(rawValue: monedaRaw) ?? .ars
    }

    private var esValido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
            && (Formatters.parsearMonto(metaTexto) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Objetivo") {
                    TextField("Nombre (ej: Vacaciones)", text: $nombre)
                    Picker("Moneda", selection: $monedaRaw) {
                        ForEach(Moneda.allCases) { moneda in
                            Text("\(moneda.simbolo) · \(moneda.nombre)").tag(moneda.rawValue)
                        }
                    }
                    HStack {
                        Text("Meta")
                        Spacer()
                        Text(moneda.simbolo)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $metaTexto)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Ahorrado")
                        Spacer()
                        Text(moneda.simbolo)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $ahorradoTexto)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Ícono") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(Self.iconos, id: \.self) { simbolo in
                            Button {
                                icono = simbolo
                                Haptics.seleccion()
                            } label: {
                                Image(systemName: simbolo)
                                    .font(.system(size: 16))
                                    .foregroundStyle(icono == simbolo ? Color(hex: colorHex) : .secondary)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle().fill(
                                            icono == simbolo
                                                ? Color(hex: colorHex).opacity(0.18)
                                                : Color.rellenoTerciario
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(Self.paleta, id: \.self) { hex in
                            Button {
                                colorHex = hex
                                Haptics.seleccion()
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if colorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(objetivoEditado == nil ? "Nuevo objetivo" : "Editar objetivo")
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
        guard let meta = Formatters.parsearMonto(metaTexto) else { return }
        let ahorrado = Formatters.parsearMonto(ahorradoTexto) ?? 0

        if let objetivo = objetivoEditado {
            objetivo.nombre = nombre.trimmingCharacters(in: .whitespaces)
            objetivo.meta = meta
            objetivo.ahorrado = ahorrado
            objetivo.icono = icono
            objetivo.colorHex = colorHex
            objetivo.monedaRaw = monedaRaw
        } else {
            contexto.insert(ObjetivoAhorro(
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                icono: icono,
                colorHex: colorHex,
                meta: meta,
                ahorrado: ahorrado,
                moneda: moneda
            ))
        }
        try? contexto.save()
        Haptics.exito()
        dismiss()
    }
}
