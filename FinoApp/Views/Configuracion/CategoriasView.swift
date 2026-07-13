import SwiftUI

/// Alta, edición, baja y reordenamiento de categorías, agrupadas por tipo.
/// Las de fábrica se editan mediante "ajustes" restaurables; las
/// personalizadas se editan y borran directamente.
struct CategoriasView: View {

    @State private var categorias = CustomCategoryStore.todas()
    @State private var formulario: FormularioCategoria?
    @State private var fabricaEnEdicion: SeleccionFabrica?
    @State private var modoEdicion: EditMode = .inactive
    /// Se incrementa al reordenar o ajustar una de fábrica, para refrescar.
    @State private var versionOrden = 0

    /// Categoría de fábrica elegida para editar.
    private struct SeleccionFabrica: Identifiable {
        let base: any CategoriaInfo
        let tipo: TipoMovimiento
        var id: String { "\(tipo.rawValue)-\(base.rawValue)" }
    }

    var body: some View {
        List {
            ForEach(TipoMovimiento.allCases) { tipo in
                Section(tipo.nombrePlural) {
                    ForEach(ordenadas(para: tipo)) { item in
                        if let personalizada = item.base as? CategoriaPersonalizada {
                            Button {
                                formulario = .editar(personalizada)
                            } label: {
                                fila(item.base, esPersonalizada: true)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    CustomCategoryStore.eliminar(id: personalizada.id)
                                    categorias = CustomCategoryStore.todas()
                                    Haptics.advertencia()
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        } else {
                            let oculta = CustomCategoryStore.estaOculta(item.base.rawValue, tipo: tipo)
                            Button {
                                fabricaEnEdicion = SeleccionFabrica(base: item.base, tipo: tipo)
                            } label: {
                                fila(
                                    item.base,
                                    esPersonalizada: true,
                                    editada: CustomCategoryStore.tieneAjuste(para: item.base.rawValue, tipo: tipo),
                                    oculta: oculta
                                )
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if oculta {
                                    Button {
                                        CustomCategoryStore.mostrar(item.base.rawValue, tipo: tipo)
                                        versionOrden += 1
                                        Haptics.exito()
                                    } label: {
                                        Label("Mostrar", systemImage: "eye.fill")
                                    }
                                    .tint(.green)
                                } else if item.base.rawValue != tipo.categoriaPorDefecto.rawValue {
                                    // "Otros" (y "Cashback") no se pueden ocultar:
                                    // siempre tiene que quedar una categoría comodín.
                                    Button(role: .destructive) {
                                        CustomCategoryStore.ocultar(item.base.rawValue, tipo: tipo)
                                        versionOrden += 1
                                        Haptics.advertencia()
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .onMove { origen, destino in
                        mover(origen, a: destino, tipo: tipo)
                    }
                }
            }

            Section {
            } footer: {
                Text("Tocá cualquier categoría para cambiarle el nombre, el ícono o el color, y con \"Ordenar\" arrastrás para elegir en qué orden aparecen. Deslizá para eliminar: las de fábrica quedan ocultas (tus movimientos viejos no se tocan) y las recuperás deslizando de nuevo. \"Otros\" no se puede ocultar. Si borrás una personalizada, sus movimientos dejan de mostrarla en los gráficos.")
            }
        }
        .scrollContentBackground(.hidden)
        // Deja pasar el último renglón por encima de la barra inferior.
        .contentMargins(.bottom, 84, for: .scrollContent)
        .background(Color.fondoPantalla)
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(modoEdicion == .active ? "Listo" : "Ordenar") {
                    withAnimation {
                        modoEdicion = modoEdicion == .active ? .inactive : .active
                    }
                }
                Button {
                    formulario = .nueva
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nueva categoría")
            }
        }
        .environment(\.editMode, $modoEdicion)
        .sheet(item: $formulario) { formulario in
            CategoriaFormSheet(existente: formulario.categoria) { _ in
                categorias = CustomCategoryStore.todas()
            }
        }
        .sheet(item: $fabricaEnEdicion) { seleccion in
            AjusteFabricaSheet(categoria: seleccion.base, tipo: seleccion.tipo) {
                versionOrden += 1
            }
        }
    }

    /// Todas las categorías del tipo en el orden guardado. Lee `categorias`
    /// y `versionOrden` para que SwiftUI refresque al cambiar cualquiera.
    private func ordenadas(para tipo: TipoMovimiento) -> [CategoriaEnvuelta] {
        _ = categorias
        _ = versionOrden
        return CustomCategoryStore.categoriasOrdenadas(para: tipo, incluyendoOcultas: true)
            .map(CategoriaEnvuelta.init)
    }

    private func mover(_ origen: IndexSet, a destino: Int, tipo: TipoMovimiento) {
        var raws = CustomCategoryStore.categoriasOrdenadas(para: tipo, incluyendoOcultas: true).map(\.rawValue)
        raws.move(fromOffsets: origen, toOffset: destino)
        CustomCategoryStore.guardarOrden(raws, para: tipo)
        versionOrden += 1
        Haptics.exito()
    }

    private func fila(
        _ categoria: any CategoriaInfo,
        esPersonalizada: Bool,
        editada: Bool = false,
        oculta: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: categoria.icono)
                .font(.subheadline)
                .foregroundStyle(categoria.color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(categoria.color.opacity(0.15)))
            Text(categoria.nombre)
                .foregroundStyle(.primary)
            Spacer()
            if oculta {
                Text("Oculta")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if editada {
                Text("Editada")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if esPersonalizada {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(oculta ? 0.4 : 1)
    }
}

/// Qué formulario abrir: alta o edición de una categoría existente.
private enum FormularioCategoria: Identifiable {
    case nueva
    case editar(CategoriaPersonalizada)

    var id: String {
        switch self {
        case .nueva: "nueva"
        case .editar(let categoria): categoria.id.uuidString
        }
    }

    var categoria: CategoriaPersonalizada? {
        switch self {
        case .nueva: nil
        case .editar(let categoria): categoria
        }
    }
}

/// Formulario de alta/edición de una categoría personalizada.
/// Lo usan el editor de Configuración y el alta rápida desde un movimiento.
struct CategoriaFormSheet: View {

    let existente: CategoriaPersonalizada?
    let alGuardar: (CategoriaPersonalizada) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nombre: String
    @State private var tipo: TipoMovimiento
    @State private var icono: String
    @State private var colorHex: String

    static let iconos = [
        "fork.knife", "cart.fill", "car.fill", "bus.fill", "house.fill",
        "cross.case.fill", "popcorn.fill", "tshirt.fill", "airplane",
        "graduationcap.fill", "bolt.fill", "pawprint.fill", "gift.fill",
        "shippingbox.fill", "gamecontroller.fill", "cup.and.saucer.fill",
        "dumbbell.fill", "fuelpump.fill", "banknote.fill", "briefcase.fill",
        "chart.line.uptrend.xyaxis", "laptopcomputer", "creditcard.fill",
        "music.note", "book.fill", "scissors", "wrench.and.screwdriver.fill",
        "star.fill", "heart.fill", "ellipsis.circle.fill"
    ]

    private static let paleta = Paleta.colores

    init(
        existente: CategoriaPersonalizada?,
        tipoInicial: TipoMovimiento = .gasto,
        alGuardar: @escaping (CategoriaPersonalizada) -> Void
    ) {
        self.existente = existente
        self.alGuardar = alGuardar
        _nombre = State(initialValue: existente?.nombre ?? "")
        _tipo = State(initialValue: existente?.tipo ?? tipoInicial)
        _icono = State(initialValue: existente?.icono ?? "star.fill")
        _colorHex = State(initialValue: existente?.colorHex ?? "6366F1")
    }

    private var esValida: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej: Café, Gimnasio, Farmacia", text: $nombre)
                }

                Section("Tipo") {
                    Picker("Tipo", selection: $tipo) {
                        ForEach(TipoMovimiento.allCases) { tipo in
                            Label(tipo.nombre, systemImage: tipo.icono).tag(tipo)
                        }
                    }
                    // Cambiar el tipo de una categoría existente dejaría
                    // huérfanos a sus movimientos, por eso se bloquea.
                    .disabled(existente != nil)
                }

                Section("Ícono") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(Self.iconos, id: \.self) { simbolo in
                            Button {
                                icono = simbolo
                                Haptics.seleccion()
                            } label: {
                                Image(systemName: simbolo)
                                    .font(.subheadline)
                                    .foregroundStyle(icono == simbolo ? .white : .primary)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        Circle().fill(icono == simbolo
                                            ? Color(hex: colorHex)
                                            : Color.rellenoTerciario)
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
            .navigationTitle(existente == nil ? "Nueva categoría" : "Editar categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .fontWeight(.semibold)
                        .disabled(!esValida)
                }
            }
        }
    }

    private func guardar() {
        let limpio = nombre.trimmingCharacters(in: .whitespaces)
        let resultado: CategoriaPersonalizada
        if let existente {
            resultado = CategoriaPersonalizada(
                id: existente.id,
                tipoRaw: existente.tipoRaw,
                nombre: limpio,
                icono: icono,
                colorHex: colorHex
            )
            CustomCategoryStore.actualizar(resultado)
        } else {
            resultado = CustomCategoryStore.agregar(
                nombre: limpio, tipo: tipo, icono: icono, colorHex: colorHex
            )
        }
        alGuardar(resultado)
        Haptics.exito()
        dismiss()
    }
}

/// Edición de una categoría de fábrica: el nombre, ícono y color nuevos
/// se guardan como "ajuste" aparte y el original siempre se puede restaurar.
struct AjusteFabricaSheet: View {

    let categoria: any CategoriaInfo
    let tipo: TipoMovimiento
    let alGuardar: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nombre: String
    @State private var icono: String
    /// Vacío significa "mantener el color actual".
    @State private var colorHex: String

    init(categoria: any CategoriaInfo, tipo: TipoMovimiento, alGuardar: @escaping () -> Void) {
        self.categoria = categoria
        self.tipo = tipo
        self.alGuardar = alGuardar
        let ajuste = CustomCategoryStore.ajuste(para: categoria.rawValue, tipo: tipo)
        _nombre = State(initialValue: ajuste?.nombre ?? categoria.nombre)
        _icono = State(initialValue: ajuste?.icono ?? categoria.icono)
        _colorHex = State(initialValue: ajuste?.colorHex ?? "")
    }

    private var esValida: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var colorActual: Color {
        colorHex.isEmpty ? categoria.color : Color(hex: colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField(categoria.nombre, text: $nombre)
                }

                Section("Ícono") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(CategoriaFormSheet.iconos, id: \.self) { simbolo in
                            Button {
                                icono = simbolo
                                Haptics.seleccion()
                            } label: {
                                Image(systemName: simbolo)
                                    .font(.subheadline)
                                    .foregroundStyle(icono == simbolo ? .white : .primary)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        Circle().fill(icono == simbolo
                                            ? colorActual
                                            : Color.rellenoTerciario)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(Paleta.colores, id: \.self) { hex in
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

                if CustomCategoryStore.tieneAjuste(para: categoria.rawValue, tipo: tipo) {
                    Section {
                        Button("Restaurar original", role: .destructive) {
                            CustomCategoryStore.restaurarAjuste(para: categoria.rawValue, tipo: tipo)
                            alGuardar()
                            Haptics.exito()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Editar categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .fontWeight(.semibold)
                        .disabled(!esValida)
                }
            }
        }
    }

    private func guardar() {
        CustomCategoryStore.guardarAjuste(
            CustomCategoryStore.AjusteCategoria(
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                icono: icono,
                colorHex: colorHex.isEmpty ? nil : colorHex
            ),
            para: categoria.rawValue,
            tipo: tipo
        )
        alGuardar()
        Haptics.exito()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CategoriasView()
    }
}
