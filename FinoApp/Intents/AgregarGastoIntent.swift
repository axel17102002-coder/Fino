import AppIntents
import SwiftData
import SwiftUI

/// Señales que los App Intents le mandan a la interfaz de la app.
@MainActor
@Observable
final class AccionesRapidas {
    static let shared = AccionesRapidas()
    /// Cuando es `true`, RootTabView abre el formulario de nuevo movimiento.
    var abrirAltaMovimiento = false
}

// MARK: - Borrador compartido entre el intent y el snippet

/// Qué está mostrando la tarjeta de confirmación.
enum ModoSnippetGasto {
    case resumen
    case eligiendoCategoria
    case eligiendoCuenta
}

/// Estado del gasto mientras se confirma en el snippet de la Dynamic Island.
/// El intent principal lo carga, los botones del snippet lo modifican y
/// recién al tocar "Continuar" se guarda en la base.
@MainActor
final class BorradorGastoRapido {
    static let shared = BorradorGastoRapido()

    var monto: Double = 0
    var nombre: String = ""
    var modo: ModoSnippetGasto = .resumen

    /// Categorías disponibles (de fábrica + personalizadas) y la elegida.
    var categorias: [(raw: String, nombre: String)] = []
    var indiceCategoria = 0

    /// Cuentas disponibles; en el snippet el índice 0 es "Sin cuenta".
    var cuentas: [(id: UUID, nombre: String)] = []
    var indiceCuenta = 0

    var categoriaActual: (raw: String, nombre: String) {
        categorias.indices.contains(indiceCategoria)
            ? categorias[indiceCategoria]
            : (CategoriaGasto.otros.rawValue, CategoriaGasto.otros.nombre)
    }

    var nombreCuentaActual: String {
        indiceCuenta == 0 ? "Sin cuenta" : cuentas[indiceCuenta - 1].nombre
    }

    var idCuentaActual: UUID? {
        indiceCuenta == 0 ? nil : cuentas[indiceCuenta - 1].id
    }

    func preparar(monto: Double, nombre: String) {
        self.monto = monto
        self.nombre = nombre
        modo = .resumen
        categorias = CustomCategoryStore.categoriasOrdenadas(para: .gasto)
            .map { ($0.rawValue, $0.nombre) }
        indiceCategoria = 0
        let contexto = PersistenceService.shared.container.mainContext
        let todas = (try? contexto.fetch(FetchDescriptor<Cuenta>())) ?? []
        cuentas = todas.sorted { $0.nombre < $1.nombre }.map { ($0.id, $0.nombre) }
        indiceCuenta = cuentas.isEmpty ? 0 : 1
    }
}

// MARK: - Intents de los botones del snippet

/// Muestra la lista de categorías dentro de la tarjeta.
struct MostrarCategoriasGastoIntent: AppIntent {
    static let title: LocalizedStringResource = "Elegir categoría"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        BorradorGastoRapido.shared.modo = .eligiendoCategoria
        return .result()
    }
}

/// Muestra la lista de cuentas dentro de la tarjeta.
struct MostrarCuentasGastoIntent: AppIntent {
    static let title: LocalizedStringResource = "Elegir cuenta"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        BorradorGastoRapido.shared.modo = .eligiendoCuenta
        return .result()
    }
}

/// Selecciona una categoría de la lista y vuelve al resumen.
struct ElegirCategoriaGastoIntent: AppIntent {
    static let title: LocalizedStringResource = "Seleccionar categoría"
    static let isDiscoverable = false

    @Parameter(title: "Índice")
    var indice: Int

    init() {}

    init(indice: Int) {
        self.indice = indice
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let borrador = BorradorGastoRapido.shared
        if borrador.categorias.indices.contains(indice) {
            borrador.indiceCategoria = indice
        }
        borrador.modo = .resumen
        return .result()
    }
}

/// Selecciona una cuenta de la lista (0 = "Sin cuenta") y vuelve al resumen.
struct ElegirCuentaGastoIntent: AppIntent {
    static let title: LocalizedStringResource = "Seleccionar cuenta"
    static let isDiscoverable = false

    @Parameter(title: "Índice")
    var indice: Int

    init() {}

    init(indice: Int) {
        self.indice = indice
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let borrador = BorradorGastoRapido.shared
        if indice >= 0 && indice <= borrador.cuentas.count {
            borrador.indiceCuenta = indice
        }
        borrador.modo = .resumen
        return .result()
    }
}

// MARK: - Snippet interactivo (iOS 26)

@available(iOS 26.0, *)
struct ConfirmarGastoSnippet: SnippetIntent {
    static let title: LocalizedStringResource = "Confirmar gasto"

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let borrador = BorradorGastoRapido.shared
        return .result(view: ConfirmarGastoSnippetView(
            monto: borrador.monto,
            nombre: borrador.nombre,
            modo: borrador.modo,
            categorias: borrador.categorias.map(\.nombre),
            indiceCategoria: borrador.indiceCategoria,
            cuentas: ["Sin cuenta"] + borrador.cuentas.map(\.nombre),
            indiceCuenta: borrador.indiceCuenta
        ))
    }
}

@available(iOS 26.0, *)
struct ConfirmarGastoSnippetView: View {
    let monto: Double
    let nombre: String
    let modo: ModoSnippetGasto
    let categorias: [String]
    let indiceCategoria: Int
    let cuentas: [String]
    let indiceCuenta: Int

    var body: some View {
        VStack(spacing: 18) {
            Text(monto.enMoneda)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            switch modo {
            case .resumen:
                resumen
            case .eligiendoCategoria:
                listaOpciones(
                    titulo: String(localized: "Elegí la categoría"),
                    opciones: categorias,
                    seleccionada: indiceCategoria
                ) { ElegirCategoriaGastoIntent(indice: $0) }
            case .eligiendoCuenta:
                listaOpciones(
                    titulo: String(localized: "Elegí la cuenta"),
                    opciones: cuentas,
                    seleccionada: indiceCuenta
                ) { ElegirCuentaGastoIntent(indice: $0) }
            }
        }
        .padding()
    }

    private var resumen: some View {
        VStack(spacing: 12) {
            fila(icono: "text.alignleft", titulo: String(localized: "Nombre")) {
                Text(nombre)
            }
            Button(intent: MostrarCategoriasGastoIntent()) {
                filaEditable(
                    icono: "tag.fill",
                    titulo: String(localized: "Categoría"),
                    valor: categorias.indices.contains(indiceCategoria) ? categorias[indiceCategoria] : "—"
                )
            }
            .buttonStyle(.plain)
            Button(intent: MostrarCuentasGastoIntent()) {
                filaEditable(
                    icono: "creditcard.fill",
                    titulo: String(localized: "Cuenta"),
                    valor: cuentas.indices.contains(indiceCuenta) ? cuentas[indiceCuenta] : "—"
                )
            }
            .buttonStyle(.plain)
            fila(icono: "calendar", titulo: String(localized: "Fecha")) {
                Text(Date.now.formatted(date: .numeric, time: .omitted))
            }
        }
    }

    private func listaOpciones<Intento: AppIntent>(
        titulo: String,
        opciones: [String],
        seleccionada: Int,
        intento: @escaping (Int) -> Intento
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titulo)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(Array(opciones.enumerated()), id: \.offset) { indice, nombre in
                    Button(intent: intento(indice)) {
                        HStack(spacing: 4) {
                            Text(nombre)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            if indice == seleccionada {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(
                            indice == seleccionada
                                ? AnyShapeStyle(.tint.opacity(0.25))
                                : AnyShapeStyle(.primary.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func fila(icono: String, titulo: String, @ViewBuilder valor: () -> some View) -> some View {
        HStack {
            Image(systemName: icono)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(titulo)
                .foregroundStyle(.secondary)
            Spacer()
            valor()
                .fontWeight(.medium)
        }
    }

    private func filaEditable(icono: String, titulo: String, valor: String) -> some View {
        fila(icono: icono, titulo: titulo) {
            HStack(spacing: 4) {
                Text(valor)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Intent principal

/// Carga un gasto sin abrir la app: pide monto y nombre, y muestra una
/// tarjeta de confirmación en la Dynamic Island donde se puede cambiar
/// la categoría y la cuenta antes de guardar.
struct AgregarGastoRapidoIntent: AppIntent {

    static let title: LocalizedStringResource = "Agregar gasto rápido"
    static let description = IntentDescription(
        "Carga un gasto sin abrir la app: ponés monto y nombre, y confirmás categoría y cuenta en una tarjeta emergente."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Monto", requestValueDialog: "¿Cuánto gastaste?")
    var monto: Double

    @Parameter(title: "Nombre", requestValueDialog: "¿En qué fue el gasto?")
    var nombre: String

    static var parameterSummary: some ParameterSummary {
        Summary("Agregar gasto de \(\.$monto) en \(\.$nombre)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard monto > 0 else {
            throw $monto.needsValueError("El monto tiene que ser mayor a cero.")
        }

        let borrador = BorradorGastoRapido.shared
        borrador.preparar(monto: monto, nombre: nombre.trimmingCharacters(in: .whitespaces))

        if #available(iOS 26.0, *) {
            // Tarjeta interactiva: si el usuario cancela, tira error y no se guarda.
            try await requestConfirmation(
                actionName: .continue,
                snippetIntent: ConfirmarGastoSnippet()
            )
        }

        let contexto = PersistenceService.shared.container.mainContext
        let cuentas = (try? contexto.fetch(FetchDescriptor<Cuenta>())) ?? []
        let cuentaElegida = borrador.idCuentaActual.flatMap { id in
            cuentas.first { $0.id == id }
        }

        contexto.insert(Movimiento(
            tipo: .gasto,
            nombre: borrador.nombre,
            categoriaRaw: borrador.categoriaActual.raw,
            monto: borrador.monto,
            cuenta: cuentaElegida
        ))
        try? contexto.save()

        RedondeoService.aplicar(aGastoDe: borrador.monto, en: contexto)
        NotificacionesService.verificarPresupuestos(en: contexto)
        let movimientos = (try? contexto.fetch(FetchDescriptor<Movimiento>())) ?? []
        WidgetDataService.publicar(movimientos: movimientos)

        return .result(dialog: "Listo: \(borrador.monto.enMoneda) en \(borrador.nombre) ✅")
    }
}

/// Abre la app directo en el formulario completo de nuevo movimiento.
struct AgregarGastoIntent: AppIntent {

    static let title: LocalizedStringResource = "Abrir formulario de gasto"
    static let description = IntentDescription(
        "Abre Fino directo en el formulario para cargar un movimiento."
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AccionesRapidas.shared.abrirAltaMovimiento = true
        return .result()
    }
}

/// Registra los atajos para que aparezcan solos en la app Atajos, en
/// Spotlight y como opciones del botón de acción.
struct FinoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AgregarGastoRapidoIntent(),
            phrases: [
                "Agregar gasto en \(.applicationName)",
                "Nuevo gasto en \(.applicationName)",
                "Cargar un gasto en \(.applicationName)"
            ],
            shortTitle: "Agregar gasto rápido",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: AgregarGastoIntent(),
            phrases: [
                "Abrir formulario de gasto en \(.applicationName)"
            ],
            shortTitle: "Abrir formulario",
            systemImageName: "plus.circle.fill"
        )
    }
}
