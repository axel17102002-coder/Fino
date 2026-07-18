import Foundation
import SwiftData

/// Contenido completo de un backup de la app, listo para serializar a JSON.
/// Los campos opcionales entraron en la versión 2: los backups viejos se
/// restauran igual, sin preferencias.
struct BackupFino: Codable {
    var version = 2
    let fecha: Date
    let cuentas: [CuentaBackup]
    let movimientos: [MovimientoBackup]
    let presupuestos: [PresupuestoBackup]
    let objetivos: [ObjetivoBackup]
    let categoriasPersonalizadas: [CategoriaPersonalizada]
    let preferencias: PreferenciasBackup?
    /// Deudas de gastos compartidos (desde la versión 2.1).
    let deudas: [DeudaBackup]?
}

struct DeudaBackup: Codable {
    let id: UUID
    let persona: String
    let detalle: String
    let monto: Double
    let fecha: Date
    let saldada: Bool
}

/// Personalización que vive fuera de la base: preferencias del usuario,
/// orden de categorías, ajustes de las de fábrica y ocultas.
struct PreferenciasBackup: Codable {
    let nombre: String?
    let monedaRaw: String?
    let temaRaw: String?
    let diaInicioMes: Int?
    /// `tipoRaw` → rawValues de categorías en el orden elegido.
    let ordenCategorias: [String: [String]]?
    let ajustesFabrica: [String: CustomCategoryStore.AjusteCategoria]?
    let categoriasOcultas: [String]?
}

struct CuentaBackup: Codable {
    let id: UUID
    let nombre: String
    let tipoRaw: String
    let banco: String
    let icono: String
    let colorHex: String
    let ultimosDigitos: String
    let limite: Double
    let diaCierre: Int
    let diaVencimiento: Int
    let saldoInicial: Double
    /// Posición elegida al reordenar (desde la versión 2).
    let orden: Int?
}

struct MovimientoBackup: Codable {
    let id: UUID
    let tipoRaw: String
    let nombre: String
    let categoriaRaw: String
    let monto: Double
    let fecha: Date
    let notas: String
    let cuotas: Int
    let cuentaID: UUID?
    /// Parte del monto que no es consumo propio (gastos compartidos).
    let montoAjeno: Double?
}

struct PresupuestoBackup: Codable {
    let id: UUID
    let categoriaRaw: String
    let montoMensual: Double
}

struct ObjetivoBackup: Codable {
    let id: UUID
    let nombre: String
    let icono: String
    let colorHex: String
    let meta: Double
    let ahorrado: Double
    let creado: Date
    let monedaRaw: String?
}

/// Crea y restaura backups completos en JSON. El archivo se comparte con el
/// share sheet, desde donde se puede guardar en iCloud Drive ("Guardar en
/// Archivos") para no perder los datos al reinstalar la app.
@MainActor
enum BackupService {

    /// Escribe el backup en un archivo temporal y devuelve su URL.
    static func crearArchivo(
        cuentas: [Cuenta],
        movimientos: [Movimiento],
        presupuestos: [Presupuesto],
        objetivos: [ObjetivoAhorro],
        deudas: [Deuda] = []
    ) throws -> URL {
        let backup = BackupFino(
            fecha: .now,
            cuentas: cuentas.map {
                CuentaBackup(
                    id: $0.id, nombre: $0.nombre, tipoRaw: $0.tipoRaw, banco: $0.banco,
                    icono: $0.icono, colorHex: $0.colorHex, ultimosDigitos: $0.ultimosDigitos,
                    limite: $0.limite, diaCierre: $0.diaCierre,
                    diaVencimiento: $0.diaVencimiento, saldoInicial: $0.saldoInicial,
                    orden: $0.orden
                )
            },
            movimientos: movimientos.map {
                MovimientoBackup(
                    id: $0.id, tipoRaw: $0.tipoRaw, nombre: $0.nombre,
                    categoriaRaw: $0.categoriaRaw, monto: $0.monto, fecha: $0.fecha,
                    notas: $0.notas, cuotas: $0.cuotas, cuentaID: $0.cuenta?.id,
                    montoAjeno: $0.montoAjeno
                )
            },
            presupuestos: presupuestos.map {
                PresupuestoBackup(id: $0.id, categoriaRaw: $0.categoriaRaw, montoMensual: $0.montoMensual)
            },
            objetivos: objetivos.map {
                ObjetivoBackup(
                    id: $0.id, nombre: $0.nombre, icono: $0.icono, colorHex: $0.colorHex,
                    meta: $0.meta, ahorrado: $0.ahorrado, creado: $0.creado,
                    monedaRaw: $0.monedaRaw
                )
            },
            categoriasPersonalizadas: CustomCategoryStore.todas(),
            preferencias: PreferenciasBackup(
                nombre: UserDefaults.standard.string(forKey: Preferencias.claveNombre),
                monedaRaw: UserDefaults.standard.string(forKey: Preferencias.claveMoneda),
                temaRaw: UserDefaults.standard.string(forKey: Preferencias.claveTema),
                diaInicioMes: UserDefaults.standard.integer(forKey: Preferencias.claveDiaInicioMes),
                ordenCategorias: Dictionary(uniqueKeysWithValues: TipoMovimiento.allCases.map {
                    ($0.rawValue, CustomCategoryStore.ordenGuardado(para: $0))
                }),
                ajustesFabrica: CustomCategoryStore.todosLosAjustes(),
                categoriasOcultas: CustomCategoryStore.todasLasOcultas()
            ),
            deudas: deudas.map {
                DeudaBackup(
                    id: $0.id, persona: $0.persona, detalle: $0.detalle,
                    monto: $0.monto, fecha: $0.fecha, saldada: $0.saldada
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)

        let formato = DateFormatter()
        formato.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Fino-backup-\(formato.string(from: .now)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Reemplaza TODOS los datos actuales con el contenido del backup.
    /// Devuelve la cantidad de movimientos restaurados, o `nil` si falló.
    static func restaurar(desde url: URL, en contexto: ModelContext) -> Int? {
        let accede = url.startAccessingSecurityScopedResource()
        defer { if accede { url.stopAccessingSecurityScopedResource() } }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              let backup = try? decoder.decode(BackupFino.self, from: data) else {
            return nil
        }

        try? contexto.delete(model: Movimiento.self)
        try? contexto.delete(model: Cuenta.self)
        try? contexto.delete(model: Presupuesto.self)
        try? contexto.delete(model: ObjetivoAhorro.self)
        try? contexto.delete(model: Deuda.self)

        var cuentasPorID: [UUID: Cuenta] = [:]
        for dto in backup.cuentas {
            let cuenta = Cuenta(
                nombre: dto.nombre,
                tipo: TipoCuenta(rawValue: dto.tipoRaw) ?? .efectivo,
                banco: dto.banco,
                icono: dto.icono,
                colorHex: dto.colorHex,
                ultimosDigitos: dto.ultimosDigitos,
                limite: dto.limite,
                diaCierre: dto.diaCierre,
                diaVencimiento: dto.diaVencimiento,
                saldoInicial: dto.saldoInicial
            )
            cuenta.id = dto.id
            cuenta.orden = dto.orden ?? 0
            contexto.insert(cuenta)
            cuentasPorID[dto.id] = cuenta
        }

        for dto in backup.movimientos {
            let movimiento = Movimiento(
                tipo: TipoMovimiento(rawValue: dto.tipoRaw) ?? .gasto,
                nombre: dto.nombre,
                categoriaRaw: dto.categoriaRaw,
                monto: dto.monto,
                fecha: dto.fecha,
                notas: dto.notas,
                cuotas: dto.cuotas,
                cuenta: dto.cuentaID.flatMap { cuentasPorID[$0] }
            )
            movimiento.id = dto.id
            movimiento.montoAjeno = dto.montoAjeno
            contexto.insert(movimiento)
        }

        for dto in backup.presupuestos {
            let presupuesto = Presupuesto(
                categoria: CategoriaGasto(rawValue: dto.categoriaRaw) ?? .otros,
                montoMensual: dto.montoMensual
            )
            presupuesto.id = dto.id
            presupuesto.categoriaRaw = dto.categoriaRaw
            contexto.insert(presupuesto)
        }

        for dto in backup.objetivos {
            let objetivo = ObjetivoAhorro(
                nombre: dto.nombre,
                icono: dto.icono,
                colorHex: dto.colorHex,
                meta: dto.meta,
                ahorrado: dto.ahorrado,
                moneda: Moneda(rawValue: dto.monedaRaw ?? Moneda.ars.rawValue) ?? .ars
            )
            objetivo.id = dto.id
            objetivo.creado = dto.creado
            contexto.insert(objetivo)
        }

        for dto in backup.deudas ?? [] {
            let deuda = Deuda(
                persona: dto.persona,
                detalle: dto.detalle,
                monto: dto.monto,
                fecha: dto.fecha,
                saldada: dto.saldada
            )
            deuda.id = dto.id
            contexto.insert(deuda)
        }

        CustomCategoryStore.reemplazarTodas(backup.categoriasPersonalizadas)
        restaurarPreferencias(backup.preferencias)

        try? contexto.save()
        return backup.movimientos.count
    }

    /// Aplica las preferencias del backup (versión 2 en adelante).
    private static func restaurarPreferencias(_ preferencias: PreferenciasBackup?) {
        guard let preferencias else { return }
        let defaults = UserDefaults.standard

        if let nombre = preferencias.nombre {
            defaults.set(nombre, forKey: Preferencias.claveNombre)
        }
        if let moneda = preferencias.monedaRaw {
            defaults.set(moneda, forKey: Preferencias.claveMoneda)
        }
        if let tema = preferencias.temaRaw {
            defaults.set(tema, forKey: Preferencias.claveTema)
        }
        if let dia = preferencias.diaInicioMes, dia > 0 {
            defaults.set(dia, forKey: Preferencias.claveDiaInicioMes)
        }
        if let orden = preferencias.ordenCategorias {
            for (tipoRaw, raws) in orden {
                guard let tipo = TipoMovimiento(rawValue: tipoRaw) else { continue }
                CustomCategoryStore.guardarOrden(raws, para: tipo)
            }
        }
        if let ajustes = preferencias.ajustesFabrica {
            CustomCategoryStore.reemplazarAjustes(ajustes)
        }
        if let ocultas = preferencias.categoriasOcultas {
            CustomCategoryStore.reemplazarOcultas(ocultas)
        }
    }
}
