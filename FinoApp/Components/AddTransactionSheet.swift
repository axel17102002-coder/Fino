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

    // Cashback del gasto, cargado junto con él.
    @State private var hayCashback = false
    @State private var cashback = CashbackDelGasto()

    // Gasto compartido.
    @State private var esCompartido = false
    @State private var conQuienes = ""
    @State private var partesIguales = true
    /// Monto que debe cada persona cuando las partes no son iguales.
    @State private var montosPorPersona: [String: String] = [:]
    /// Estado del reparto tal como estaba al abrir el formulario, para no
    /// tocar las deudas si la edición no cambió nada del gasto compartido
    /// (y así no perder las que ya estén marcadas como saldadas).
    @State private var esCompartidoOriginal = false
    @State private var partesOriginalesPorPersona: [String: Double] = [:]

    private let esEdicion: Bool
    private let movimientoOriginal: Movimiento?
    /// Abre la cámara de escaneo apenas aparece el formulario (lo usa el
    /// botón de la franja del Dashboard).
    private let escanearAlAbrir: Bool

    init(
        movimiento: Movimiento? = nil,
        cuentaPreseleccionada: Cuenta? = nil,
        escanearAlAbrir: Bool = false
    ) {
        _viewModel = State(initialValue: MovimientoFormViewModel(movimiento: movimiento, cuentaPreseleccionada: cuentaPreseleccionada))
        esEdicion = movimiento != nil
        movimientoOriginal = movimiento
        self.escanearAlAbrir = escanearAlAbrir
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
                        HStack(spacing: 10) {
                            if EscanerTicketView.disponible {
                                Button {
                                    mostrandoEscaner = true
                                    Haptics.seleccion()
                                } label: {
                                    capsulaTicket(
                                        String(localized: "Cámara"),
                                        "camera.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(localized: "Escanear ticket"))
                            }
                            PhotosPicker(selection: $fotoTicket, matching: .images) {
                                capsulaTicket(
                                    String(localized: "Fotos"),
                                    "photo.on.rectangle"
                                )
                            }
                            .accessibilityLabel(String(localized: "Leer ticket de una foto"))
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    } footer: {
                        Text("Lee el total, el comercio y la fecha directo del ticket. Todo pasa en tu teléfono.")
                    }
                }

                Section("Datos") {
                    TextField("Nombre", text: $viewModel.nombre)

                    // El símbolo es el selector de moneda: era una fila
                    // aparte y ahí no hacía más que repetir lo que ya
                    // mostraba el campo del monto.
                    HStack {
                        Menu {
                            Picker("Moneda", selection: $viewModel.moneda) {
                                ForEach(Moneda.allCases) { moneda in
                                    Text("\(moneda.simbolo) · \(moneda.rawValue)").tag(moneda)
                                }
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Text(viewModel.moneda.simbolo)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel(String(localized: "Moneda"))

                        TextField("0", text: $viewModel.montoTexto)
                            .keyboardType(.decimalPad)
                            .monospacedDigit()
                    }

                    if viewModel.esMonedaExtranjera {
                        conversionMoneda
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
                        if viewModel.cuotas > 1, let monto = viewModel.montoConvertido {
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

                // Cashback y compartido en un solo bloque: los dos
                // significan "este gasto además genera otro movimiento"
                // —plata que vuelve, o lo que te deben— y separarlos los
                // hacía parecer dos temas distintos.
                if viewModel.tipo == .gasto {
                    Section("Además") {
                        if !esEdicion {
                        Toggle(isOn: $hayCashback.animation()) {
                            Label("Hubo cashback", systemImage: "arrow.counterclockwise.circle.fill")
                        }
                        if hayCashback {
                            Picker("Cómo", selection: $cashback.modo.animation()) {
                                ForEach(CashbackDelGasto.Modo.allCases) { modo in
                                    Text(modo.nombre).tag(modo)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                Text(cashback.modo == .porcentaje ? "%" : viewModel.moneda.simbolo)
                                    .foregroundStyle(.secondary)
                                TextField("0", text: $cashback.texto)
                                    .keyboardType(.decimalPad)
                                    .monospacedDigit()
                            }

                            if let devuelto = montoDeCashbackConvertido {
                                LabeledContent("Te devuelven", value: devuelto.enMoneda)
                                    .font(.subheadline)
                            }
                            nota("Queda como un movimiento de cashback aparte, con la misma fecha y la misma cuenta que el gasto.")
                        }
                        }

                        Toggle(isOn: $esCompartido.animation()) {
                            Label("Gasto compartido", systemImage: "person.2.fill")
                        }
                        if esCompartido {
                            TextField("¿Con quiénes? (separá con comas)", text: $conQuienes)
                                .autocorrectionDisabled()

                            let nombres = personasCompartidas
                            if !nombres.isEmpty {
                                if let reparto = repartoPorRenglones {
                                    LabeledContent(
                                        "Cada uno (entre \(nombres.count + 1))",
                                        value: reparto.deCadaUno.enMoneda
                                    )
                                    .font(.subheadline)
                                    LabeledContent("Tu parte", value: reparto.tuya.enMoneda)
                                        .font(.subheadline)
                                } else {
                                Toggle("Partes iguales", isOn: $partesIguales.animation())

                                if partesIguales {
                                    if let monto = viewModel.monto {
                                        LabeledContent(
                                            "Cada uno (entre \(nombres.count + 1))",
                                            value: DeudasService.parteDeCadaUno(total: monto, nombres: nombres).enMoneda
                                        )
                                        .font(.subheadline)
                                    }
                                } else {
                                    ForEach(nombres, id: \.self) { nombre in
                                        HStack {
                                            Text(nombre)
                                            Spacer()
                                            Text(Formatters.monedaActual.simbolo)
                                                .foregroundStyle(.secondary)
                                            TextField("0", text: montoBinding(para: nombre))
                                                .keyboardType(.decimalPad)
                                                .monospacedDigit()
                                                .multilineTextAlignment(.trailing)
                                                .frame(width: 110)
                                        }
                                    }
                                    if let monto = viewModel.monto {
                                        let ajeno = totalAjeno(de: nombres)
                                        LabeledContent("Tu parte", value: max(monto - ajeno, 0).enMoneda)
                                            .font(.subheadline)
                                        if ajeno > monto {
                                            Label("Las partes suman más que el gasto.", systemImage: "exclamationmark.triangle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                                }
                            }
                        }
                        if repartoPorRenglones != nil {
                            nota("El reparto sale del detalle del ticket: los renglones marcados como tuyos van enteros a tu parte y el resto se divide. Los descuentos se reparten en la misma proporción.")
                        } else if esCompartido {
                            nota("Pagaste vos: el gasto queda completo y Fino anota lo que te debe cada uno en \"Me deben\".")
                        }
                    }
                }

                seccionDetalleTicket

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
                        if let movimiento = viewModel.guardar(en: contexto) {
                            NotificacionesService.verificarPresupuestos(en: contexto)
                            if viewModel.tipo == .gasto, let monto = viewModel.monto {
                                if esEdicion {
                                    actualizarGastoCompartido(total: monto, para: movimiento)
                                } else {
                                    if esCompartido {
                                        crearDeudas(total: monto, para: movimiento)
                                    }
                                    crearCashback(delGastoDe: monto, como: movimiento)
                                    RedondeoService.aplicar(aGastoDe: monto, en: contexto)
                                }
                            }
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
                cargarGastoCompartidoExistente()
                if escanearAlAbrir && EscanerTicketView.disponible {
                    mostrandoEscaner = true
                }
            }
            .onChange(of: viewModel.tipo) { _, _ in
                recargarCategoriasPersonalizadas()
            }
            .onChange(of: viewModel.moneda) { _, _ in
                Task { await viewModel.actualizarTasa() }
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

    // MARK: - Botones de ticket

    /// Cápsula tintada con el color de acento. Las dos se reparten el ancho
    /// en partes iguales; si la cámara no está disponible, la de fotos
    /// ocupa la fila completa.
    private func capsulaTicket(_ titulo: String, _ icono: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icono)
            Text(titulo)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.15), in: Capsule())
        .contentShape(Capsule())
    }

    // MARK: - Conversión de moneda

    /// Tasa editable + previsualización del monto ya convertido a la moneda
    /// global. La tasa se precarga con la cotización oficial (dolarapi).
    @ViewBuilder
    private var conversionMoneda: some View {
        HStack {
            Text("Cotización")
            Spacer()
            if viewModel.cargandoTasa {
                ProgressView()
            }
            Text("1 \(viewModel.moneda.rawValue) =")
                .foregroundStyle(.secondary)
                .font(.callout)
            TextField("0", text: $viewModel.tasaTexto)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 90)
            Text(viewModel.monedaGlobal.rawValue)
                .foregroundStyle(.secondary)
                .font(.callout)
        }

        if let convertido = viewModel.montoConvertido {
            LabeledContent("Equivale a", value: Formatters.moneda(convertido, moneda: viewModel.monedaGlobal))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Gasto compartido

    /// Campo de monto de una persona; al aparecer se precarga con la
    /// parte igualitaria para que solo haya que ajustar.
    private func montoBinding(para nombre: String) -> Binding<String> {
        Binding(
            get: {
                if let guardado = montosPorPersona[nombre] { return guardado }
                let nombres = DeudasService.nombres(desde: conQuienes)
                guard let monto = viewModel.monto else { return "" }
                let parte = DeudasService.parteDeCadaUno(total: monto, nombres: nombres)
                return parte > 0 ? String(Int(parte)) : ""
            },
            set: { montosPorPersona[nombre] = $0 }
        )
    }

    private func totalAjeno(de nombres: [String]) -> Double {
        nombres.reduce(0) { acumulado, nombre in
            acumulado + (Formatters.parsearMonto(montoBinding(para: nombre).wrappedValue) ?? 0)
        }
    }

    /// Reparto vigente en el formulario, en la moneda del gasto.
    private func partesActuales(total: Double) -> [(persona: String, monto: Double)] {
        let nombres = personasCompartidas
        if let reparto = repartoPorRenglones {
            return nombres.map { ($0, reparto.deCadaUno) }
        } else if partesIguales {
            let parte = DeudasService.parteDeCadaUno(total: total, nombres: nombres)
            return nombres.map { ($0, parte) }
        } else {
            return nombres.compactMap { nombre -> (persona: String, monto: Double)? in
                guard let monto = Formatters.parsearMonto(montoBinding(para: nombre).wrappedValue),
                      monto > 0 else { return nil }
                return (nombre, monto)
            }
        }
    }

    /// Explicación de una opción, debajo de sus campos.
    ///
    /// Antes cada opción era su propia sección y esto vivía en el `footer`.
    /// Al juntarlas en un bloque solo quedaría un pie para las dos, así
    /// que la nota baja al renglón y aparece únicamente con la opción
    /// prendida.
    private func nota(_ texto: String) -> some View {
        Text(texto)
            .font(.caption)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden)
    }

    /// Lo que devuelve el cashback, ya en la moneda global (que es la que
    /// se guarda y la que suman los totales).
    private var montoDeCashbackConvertido: Double? {
        guard hayCashback,
              let monto = viewModel.monto,
              let devuelto = cashback.monto(sobre: monto)
        else { return nil }
        return viewModel.esMonedaExtranjera ? devuelto * (viewModel.tasa ?? 1) : devuelto
    }

    /// Da de alta el movimiento de cashback junto con el gasto.
    ///
    /// Hereda la fecha y la cuenta del gasto a propósito: la gracia es no
    /// tener que cargar dos veces la misma compra, y pedir una fecha
    /// aparte devolvería justo ese trabajo. Si el reintegro cae otro día,
    /// el movimiento queda creado y se edita como cualquier otro.
    private func crearCashback(delGastoDe monto: Double, como gasto: Movimiento) {
        guard hayCashback, let devuelto = cashback.monto(sobre: monto), devuelto > 0 else { return }

        let movimiento = Movimiento(
            tipo: .cashback,
            nombre: String(localized: "Cashback \(viewModel.nombre)"),
            categoriaRaw: CategoriaCashback.cashback.rawValue,
            monto: viewModel.esMonedaExtranjera ? devuelto * (viewModel.tasa ?? 1) : devuelto,
            fecha: gasto.fecha
        )
        movimiento.cuenta = gasto.cuenta
        // En otra moneda se guardan las dos, igual que el gasto: el
        // reintegro de una compra en dólares también es en dólares.
        if viewModel.esMonedaExtranjera {
            movimiento.monedaOriginalRaw = viewModel.moneda.rawValue
            movimiento.montoOriginal = devuelto
            movimiento.tasaCambio = viewModel.tasa
        }
        contexto.insert(movimiento)
        try? contexto.save()
    }

    private func crearDeudas(total: Double, para movimiento: Movimiento) {
        let partes = partesActuales(total: total)
        DeudasService.crear(
            partes: partes,
            detalle: viewModel.nombre,
            movimientoID: movimiento.id,
            moneda: viewModel.moneda,
            tasa: viewModel.tasa,
            en: contexto
        )
        // El gasto recuerda cuánto es de otros: las métricas del mes
        // cuentan solo tu parte.
        //
        // Convertido a la moneda global, porque `monto` también lo está:
        // sin esto, un gasto compartido en dólares restaba 33 (dólares) a
        // un monto de 60.000 (pesos) y "tu parte" daba cualquier cosa.
        let ajenoEnMonedaDelGasto = partes.reduce(0) { $0 + $1.monto }
        movimiento.montoAjeno = viewModel.esMonedaExtranjera
            ? ajenoEnMonedaDelGasto * (viewModel.tasa ?? 1)
            : ajenoEnMonedaDelGasto
        try? contexto.save()
    }

    /// Al editar, precarga el toggle, los nombres y los montos desde las
    /// deudas ya vinculadas al movimiento (si las hay), para que se vean y
    /// se puedan cambiar en vez de arrancar siempre en blanco.
    private func cargarGastoCompartidoExistente() {
        guard let movimiento = movimientoOriginal, movimiento.tipo == .gasto else { return }
        let deudas = ((try? contexto.fetch(FetchDescriptor<Deuda>())) ?? [])
            .filter { $0.movimientoID == movimiento.id }
        guard !deudas.isEmpty else { return }

        esCompartido = true
        esCompartidoOriginal = true
        conQuienes = deudas.map(\.persona).joined(separator: ", ")

        let montoPorPersona = Dictionary(uniqueKeysWithValues: deudas.map { ($0.persona, $0.montoOriginal ?? $0.monto) })
        partesOriginalesPorPersona = montoPorPersona

        let montos = Array(montoPorPersona.values)
        partesIguales = montos.max().map { mayor in montos.allSatisfy { abs($0 - mayor) < 0.01 } } ?? true
        if !partesIguales {
            montosPorPersona = montoPorPersona.mapValues { Formatters.montoEditable($0, moneda: viewModel.moneda) }
        }
    }

    /// Solo toca las deudas si el reparto cambió de verdad: así una
    /// edición que no toca el gasto compartido no pisa deudas que ya
    /// estén marcadas como saldadas.
    private func actualizarGastoCompartido(total: Double, para movimiento: Movimiento) {
        guard gastoCompartidoCambio(total: total) else { return }
        DeudasService.eliminarVinculadas(a: movimiento.id, en: contexto)
        if esCompartido {
            crearDeudas(total: total, para: movimiento)
        } else {
            movimiento.montoAjeno = nil
            try? contexto.save()
        }
    }

    private func gastoCompartidoCambio(total: Double) -> Bool {
        guard esCompartido == esCompartidoOriginal else { return true }
        guard esCompartido else { return false }
        let actuales = Dictionary(uniqueKeysWithValues: partesActuales(total: total).map { ($0.persona, $0.monto) })
        guard actuales.count == partesOriginalesPorPersona.count else { return true }
        return actuales.contains { persona, monto in
            guard let original = partesOriginalesPorPersona[persona] else { return true }
            return abs(monto - original) >= 0.01
        }
    }

    /// Personas nombradas para dividir el gasto.
    private var personasCompartidas: [String] {
        DeudasService.nombres(desde: conQuienes)
    }

    /// El reparto sale de los renglones del ticket en vez de dividir el
    /// total: hay detalle, hay con quién dividir, y alguno de los
    /// renglones está marcado como tuyo.
    private var repartoPorRenglones: (tuya: Double, deCadaUno: Double)? {
        guard esCompartido, !viewModel.items.isEmpty, let monto = viewModel.monto else { return nil }
        return viewModel.items.reparto(
            entrePersonas: personasCompartidas.count,
            totalPagado: monto
        )
    }

    /// Renglones leídos del ticket. Se puede borrar cualquiera que el OCR
    /// haya inventado; el monto del gasto no se toca, porque el total
    /// impreso es más confiable que la suma de lo que se pudo leer.
    @ViewBuilder
    private var seccionDetalleTicket: some View {
        if !viewModel.items.isEmpty {
            Section {
                ForEach(Array(viewModel.items.enumerated()), id: \.offset) { indice, item in
                    HStack {
                        // Solo cuando hay con quién dividir: si no, la
                        // marca no cambia nada y estorba.
                        if esCompartido, item.monto > 0 {
                            Button {
                                viewModel.items[indice].soloMio.toggle()
                                Haptics.seleccion()
                            } label: {
                                Image(systemName: item.soloMio ? "person.fill" : "person.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(item.soloMio ? Color.accentColor : .secondary)
                                    .frame(width: 26)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.soloMio
                                ? String(localized: "Solo mío, tocá para compartir")
                                : String(localized: "Compartido, tocá para marcarlo como solo mío"))
                        }

                        Text(item.nombre)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        // Los descuentos van en verde: son el único
                        // renglón que resta y así se distingue de un
                        // producto sin tener que leer el signo.
                        Text(item.monto.enMoneda)
                            .monospacedDigit()
                            .foregroundStyle(item.monto < 0 ? Color.verdeIngreso : .secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.items.remove(at: indice)
                        } label: {
                            Label("Quitar", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Detalle del ticket")
                    Spacer()
                    Text("\(viewModel.items.count) ítems")
                }
            } footer: {
                if esCompartido {
                    Text("Tocá el ícono de cada renglón para marcarlo como solo tuyo. Los tuyos van enteros a tu parte y el resto se divide.")
                } else if viewModel.itemsCuadranConElMonto {
                    Text("Suman \(viewModel.totalDeItems.enMoneda). Deslizá para quitar un renglón.")
                } else {
                    Label(
                        "Los renglones suman \(viewModel.totalDeItems.enMoneda) y el total cargado es otro. Puede que falte algún producto o que se haya colado una línea que no lo es.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
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
            // El historial sugiere la categoría para este comercio.
            if let sugerida = CategoriaPredictorService.categoria(paraGasto: nombre, en: contexto) {
                viewModel.categoriaRaw = sugerida
            }
        }
        if let fecha = datos.fecha {
            viewModel.fecha = fecha
        }
        viewModel.items = datos.items
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
