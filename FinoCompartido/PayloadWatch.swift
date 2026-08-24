import Foundation

/// Contrato entre el iPhone y el Apple Watch.
///
/// Este archivo lo compilan los dos targets (Fino y FinoWatch): no hay
/// copias. Si cambian los campos y una punta queda vieja, el JSON deja de
/// decodificar y el reloj se queda mudo sin avisar, así que conviene
/// tocarlo siempre acá.
///
/// El iPhone manda **snapshots completos**, no diferencias: la sincro usa
/// `updateApplicationContext`, que pisa el estado anterior en vez de
/// encolarlo. Siempre gana el último enviado y el reloj no reconstruye
/// nada. Los gastos que van en sentido contrario (reloj → iPhone) sí van
/// de a uno por `transferUserInfo`, que encola y garantiza la entrega
/// aunque el teléfono esté dormido.
enum PayloadWatch {

    /// Clave del diccionario que viaja en `updateApplicationContext`.
    static let claveSnapshot = "snapshot"

    /// Clave del diccionario que viaja en `transferUserInfo`.
    static let claveGasto = "gastoNuevo"

    /// App Group del reloj: lo comparten la app y su complicación, que
    /// corren en el mismo dispositivo pero en contenedores distintos.
    /// Es el mismo grupo que usa el widget del iPhone; los App Groups son
    /// por equipo, no por plataforma.
    static let grupo = "group.com.axelmorano.FinoApp"

    /// Clave del snapshot guardado en el App Group del reloj.
    static let claveSnapshotGuardado = "snapshotDelIPhone"

    /// Enlaces profundos que la complicación usa para abrir la app.
    enum Enlace {
        static let esquema = "fino"
        static let nuevoGasto = URL(string: "fino://nueva")!
        static let resumen = URL(string: "fino://resumen")!
    }
}

// MARK: - iPhone → reloj

/// Foto del mes que el iPhone le publica al reloj.
///
/// Los campos son `var` porque el reloj aplica de prepo el gasto que
/// acaba de cargar sobre el último snapshot, para no mostrar la dona
/// desactualizada mientras espera que el iPhone confirme. El próximo
/// snapshot real pisa esa cuenta optimista.
struct SnapshotWatch: Codable, Equatable {

    /// Una porción de la dona: lo gastado en una categoría este mes.
    struct PorcionCategoria: Codable, Equatable, Identifiable {
        let raw: String
        let nombre: String
        let icono: String
        let colorHex: String
        let monto: Double

        var id: String { raw }
    }

    /// Categoría elegible al cargar un gasto desde el reloj.
    ///
    /// Viaja resuelta (nombre, ícono y color ya pisados por los ajustes
    /// del usuario) para que el reloj no tenga que conocer
    /// `CustomCategoryStore` ni los enums de categorías.
    struct CategoriaDisponible: Codable, Equatable, Identifiable {
        let raw: String
        let nombre: String
        let icono: String
        let colorHex: String

        var id: String { raw }
    }

    /// Movimiento recortado a lo que entra en la pantalla del reloj.
    struct MovimientoResumido: Codable, Equatable, Identifiable {
        let id: UUID
        let nombre: String
        let icono: String
        let colorHex: String
        let monto: Double
        let esGasto: Bool
        let fecha: Date
    }

    /// Cuándo se armó el snapshot. Es `var` a propósito: el iPhone lo
    /// normaliza antes de comparar contra el último enviado, así un
    /// snapshot idéntico salvo la hora no gasta batería de más.
    var generado: Date

    /// Mes financiero que describe el snapshot, ya formateado ("Agosto 2026").
    var mes: String

    /// Símbolo y decimales de la moneda global, para que el reloj formatee
    /// igual que el iPhone sin conocer el enum `Moneda`.
    var simboloMoneda: String
    var decimales: Int

    /// El usuario tiene activado el modo privacidad (el ojito del
    /// Dashboard). El reloj también tapa los montos.
    var montosOcultos: Bool

    var gastos: Double
    var ingresos: Double
    var balance: Double

    /// Gastos del mes por categoría, de mayor a menor: es la dona.
    var porCategoria: [PorcionCategoria]

    /// Catálogo para el alta rápida, en el orden que el usuario configuró.
    var categorias: [CategoriaDisponible]

    /// Últimos movimientos, del más nuevo al más viejo.
    var ultimos: [MovimientoResumido]

    static let vacio = SnapshotWatch(
        generado: .distantPast,
        mes: "",
        simboloMoneda: "$",
        decimales: 0,
        montosOcultos: false,
        gastos: 0,
        ingresos: 0,
        balance: 0,
        porCategoria: [],
        categorias: [],
        ultimos: []
    )
}

// MARK: - Reloj → iPhone

/// Gasto cargado en el reloj, en camino al iPhone.
///
/// Viaja con `id` propio para que el iPhone pueda descartar duplicados:
/// `transferUserInfo` garantiza la entrega, no que sea exactamente una.
struct GastoDelWatch: Codable, Equatable, Identifiable {
    let id: UUID
    let monto: Double
    let categoriaRaw: String
    let nombre: String
    let fecha: Date

    init(
        id: UUID = UUID(),
        monto: Double,
        categoriaRaw: String,
        nombre: String,
        fecha: Date = .now
    ) {
        self.id = id
        self.monto = monto
        self.categoriaRaw = categoriaRaw
        self.nombre = nombre
        self.fecha = fecha
    }
}
