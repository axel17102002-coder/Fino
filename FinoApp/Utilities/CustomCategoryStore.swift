import SwiftUI

/// Categoría creada por el usuario y guardada en preferencias locales.
struct CategoriaPersonalizada: Codable, Identifiable, CategoriaInfo {
    let id: UUID
    let tipoRaw: String
    let nombre: String
    let icono: String
    let colorHex: String

    var rawValue: String { "custom_\(id.uuidString)" }
    var color: Color { Color(hex: colorHex) }

    var tipo: TipoMovimiento? {
        TipoMovimiento(rawValue: tipoRaw)
    }
}

/// Persistencia liviana para categorías personalizadas.
enum CustomCategoryStore {
    private static let clave = "categoriasPersonalizadas"

    static func todas() -> [CategoriaPersonalizada] {
        guard let data = UserDefaults.standard.data(forKey: clave),
              let categorias = try? JSONDecoder().decode([CategoriaPersonalizada].self, from: data) else {
            return []
        }
        return categorias
    }

    static func categorias(para tipo: TipoMovimiento) -> [CategoriaPersonalizada] {
        todas().filter { $0.tipoRaw == tipo.rawValue }
    }

    static func categoria(raw: String, tipo: TipoMovimiento) -> CategoriaPersonalizada? {
        categorias(para: tipo).first { $0.rawValue == raw }
    }

    /// Reemplaza la categoría que tenga el mismo `id`.
    static func actualizar(_ categoria: CategoriaPersonalizada) {
        guardar(todas().map { $0.id == categoria.id ? categoria : $0 })
    }

    static func eliminar(id: UUID) {
        guardar(todas().filter { $0.id != id })
    }

    /// Reemplaza todas las categorías guardadas (usado al restaurar un backup).
    static func reemplazarTodas(_ categorias: [CategoriaPersonalizada]) {
        guardar(categorias)
    }

    @discardableResult
    static func agregar(nombre: String, tipo: TipoMovimiento, icono: String, colorHex: String) -> CategoriaPersonalizada {
        let categoria = CategoriaPersonalizada(
            id: UUID(),
            tipoRaw: tipo.rawValue,
            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
            icono: icono,
            colorHex: colorHex
        )
        guardar(todas() + [categoria])
        return categoria
    }

    private static func guardar(_ categorias: [CategoriaPersonalizada]) {
        guard let data = try? JSONEncoder().encode(categorias) else { return }
        UserDefaults.standard.set(data, forKey: clave)
    }

    // MARK: - Ajustes de categorías de fábrica

    /// Cambios del usuario sobre una categoría de fábrica. Los campos en
    /// `nil` conservan el valor original.
    struct AjusteCategoria: Codable {
        var nombre: String?
        var icono: String?
        var colorHex: String?
    }

    private static let claveAjustes = "ajustesCategoriasFabrica"
    /// Cache en memoria: `nombre`/`icono`/`color` se consultan en cada
    /// render y no queremos decodificar JSON cada vez.
    private static var cacheAjustes: [String: AjusteCategoria]?

    private static func claveDe(_ raw: String, _ tipo: TipoMovimiento) -> String {
        // El tipo forma parte de la clave porque hay rawValues repetidos
        // entre tipos (ej: "otros" existe en gastos e ingresos).
        "\(tipo.rawValue)-\(raw)"
    }

    private static func ajustes() -> [String: AjusteCategoria] {
        if let cacheAjustes { return cacheAjustes }
        let cargados: [String: AjusteCategoria]
        if let data = UserDefaults.standard.data(forKey: claveAjustes),
           let decodificados = try? JSONDecoder().decode([String: AjusteCategoria].self, from: data) {
            cargados = decodificados
        } else {
            cargados = [:]
        }
        cacheAjustes = cargados
        return cargados
    }

    static func ajuste(para raw: String, tipo: TipoMovimiento) -> AjusteCategoria? {
        ajustes()[claveDe(raw, tipo)]
    }

    static func tieneAjuste(para raw: String, tipo: TipoMovimiento) -> Bool {
        ajuste(para: raw, tipo: tipo) != nil
    }

    static func guardarAjuste(_ ajuste: AjusteCategoria, para raw: String, tipo: TipoMovimiento) {
        var actuales = ajustes()
        actuales[claveDe(raw, tipo)] = ajuste
        persistirAjustes(actuales)
    }

    static func restaurarAjuste(para raw: String, tipo: TipoMovimiento) {
        var actuales = ajustes()
        actuales.removeValue(forKey: claveDe(raw, tipo))
        persistirAjustes(actuales)
    }

    // Acceso completo para el backup.

    static func todosLosAjustes() -> [String: AjusteCategoria] {
        ajustes()
    }

    static func reemplazarAjustes(_ nuevos: [String: AjusteCategoria]) {
        persistirAjustes(nuevos)
    }

    private static func persistirAjustes(_ ajustes: [String: AjusteCategoria]) {
        cacheAjustes = ajustes
        guard let data = try? JSONEncoder().encode(ajustes) else { return }
        UserDefaults.standard.set(data, forKey: claveAjustes)
    }

    // MARK: - Categorías de fábrica ocultas ("eliminadas" por el usuario)

    private static let claveOcultas = "categoriasFabricaOcultas"

    private static func ocultas() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: claveOcultas) ?? [])
    }

    static func estaOculta(_ raw: String, tipo: TipoMovimiento) -> Bool {
        ocultas().contains(claveDe(raw, tipo))
    }

    static func ocultar(_ raw: String, tipo: TipoMovimiento) {
        UserDefaults.standard.set(
            Array(ocultas().union([claveDe(raw, tipo)])),
            forKey: claveOcultas
        )
    }

    static func mostrar(_ raw: String, tipo: TipoMovimiento) {
        UserDefaults.standard.set(
            Array(ocultas().subtracting([claveDe(raw, tipo)])),
            forKey: claveOcultas
        )
    }

    // Acceso completo para el backup.

    static func todasLasOcultas() -> [String] {
        Array(ocultas())
    }

    static func reemplazarOcultas(_ nuevas: [String]) {
        UserDefaults.standard.set(nuevas, forKey: claveOcultas)
    }

    // MARK: - Orden elegido por el usuario (de fábrica + personalizadas)

    private static let clavePrefijoOrden = "ordenCategorias-"

    static func guardarOrden(_ raws: [String], para tipo: TipoMovimiento) {
        UserDefaults.standard.set(raws, forKey: clavePrefijoOrden + tipo.rawValue)
    }

    static func ordenGuardado(para tipo: TipoMovimiento) -> [String] {
        UserDefaults.standard.stringArray(forKey: clavePrefijoOrden + tipo.rawValue) ?? []
    }

    /// Todas las categorías del tipo (de fábrica + personalizadas) en el
    /// orden que eligió el usuario. Las que no figuran en el orden guardado
    /// (por ejemplo, recién creadas) van al final en su orden natural.
    /// Las ocultas se excluyen salvo que se pidan (el editor las muestra
    /// grisadas para poder recuperarlas).
    static func categoriasOrdenadas(
        para tipo: TipoMovimiento,
        incluyendoOcultas: Bool = false
    ) -> [any CategoriaInfo] {
        var todas: [any CategoriaInfo] = tipo.categorias + categorias(para: tipo)
        if !incluyendoOcultas {
            todas = todas.filter { !estaOculta($0.rawValue, tipo: tipo) }
        }
        let orden = ordenGuardado(para: tipo)
        guard !orden.isEmpty else { return todas }
        return todas.enumerated()
            .sorted { a, b in
                let posicionA = orden.firstIndex(of: a.element.rawValue) ?? (orden.count + a.offset)
                let posicionB = orden.firstIndex(of: b.element.rawValue) ?? (orden.count + b.offset)
                return posicionA < posicionB
            }
            .map(\.element)
    }
}
