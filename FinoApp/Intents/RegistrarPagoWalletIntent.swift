import AppIntents
import SwiftData

/// Cuenta de Fino como entidad de Atajos: permite elegirla en un menú
/// desplegable al configurar la automatización, en vez de tipear el nombre.
struct CuentaEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Cuenta"
    static let defaultQuery = CuentaQuery()

    let id: UUID
    let nombre: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(nombre)")
    }
}

struct CuentaQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CuentaEntity] {
        todas().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [CuentaEntity] {
        todas()
    }

    @MainActor
    private func todas() -> [CuentaEntity] {
        let contexto = PersistenceService.shared.container.mainContext
        let cuentas = (try? contexto.fetch(FetchDescriptor<Cuenta>())) ?? []
        return cuentas
            .sorted { $0.nombre < $1.nombre }
            .map { CuentaEntity(id: $0.id, nombre: $0.nombre) }
    }
}

/// Categoría de gasto (de fábrica + personalizadas) como entidad de Atajos.
struct CategoriaGastoEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Categoría"
    static let defaultQuery = CategoriaGastoQuery()

    /// rawValue de la categoría.
    let id: String
    let nombre: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(nombre)")
    }
}

struct CategoriaGastoQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [CategoriaGastoEntity] {
        todas().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoriaGastoEntity] {
        todas()
    }

    @MainActor
    private func todas() -> [CategoriaGastoEntity] {
        CustomCategoryStore.categoriasOrdenadas(para: .gasto)
            .map { CategoriaGastoEntity(id: $0.rawValue, nombre: $0.nombre) }
    }
}

/// Guarda un gasto directo, sin abrir la app ni pedir confirmación.
/// Pensado para la automatización de Atajos con disparador "Transacción":
/// cada pago con Apple Pay se registra solo, con el monto y el comercio
/// que informa el Wallet.
struct RegistrarPagoWalletIntent: AppIntent {

    static let title: LocalizedStringResource = "Registrar pago con tarjeta"
    static let description = IntentDescription(
        "Guarda un gasto al instante, sin abrir la app ni confirmar. Usalo en una automatización de Atajos con el disparador \"Transacción\" para registrar solos los pagos con Apple Pay.",
        categoryName: "Automatización"
    )
    static let openAppWhenRun = false

    @Parameter(title: "Monto")
    var monto: Double

    @Parameter(title: "Comercio")
    var comercio: String

    @Parameter(title: "Cuenta")
    var cuenta: CuentaEntity?

    @Parameter(title: "Categoría")
    var categoria: CategoriaGastoEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Registrar gasto de \(\.$monto) en \(\.$comercio)") {
            \.$cuenta
            \.$categoria
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard monto > 0 else {
            throw $monto.needsValueError("El monto tiene que ser mayor a cero.")
        }

        let contexto = PersistenceService.shared.container.mainContext
        let cuentaModelo: Cuenta? = cuenta.flatMap { elegida in
            let cuentas = (try? contexto.fetch(FetchDescriptor<Cuenta>())) ?? []
            return cuentas.first { $0.id == elegida.id }
        }

        let nombre = NombreComercio.limpiar(comercio)
        contexto.insert(Movimiento(
            tipo: .gasto,
            nombre: nombre.isEmpty ? String(localized: "Pago con tarjeta") : nombre,
            categoriaRaw: categoria?.id ?? CategoriaGasto.otros.rawValue,
            monto: monto,
            cuenta: cuentaModelo
        ))
        try? contexto.save()

        RedondeoService.aplicar(aGastoDe: monto, en: contexto)
        NotificacionesService.verificarPresupuestos(en: contexto)
        let movimientos = (try? contexto.fetch(FetchDescriptor<Movimiento>())) ?? []
        WidgetDataService.publicar(movimientos: movimientos)

        return .result(dialog: "💳 \(monto.enMoneda) en \(nombre) registrado en Fino")
    }
}
