import Foundation
import SwiftData

@Model
final class Movimiento {
    @Attribute(.unique) var id: UUID
    var tipoRaw: String
    var nombre: String
    var categoriaRaw: String
    var monto: Double
    var fecha: Date
    var notas: String
    /// Cantidad de cuotas de la compra. `1` significa pago único.
    var cuotas: Int
    var cuenta: Cuenta?
    /// Parte de este movimiento que NO es consumo propio.
    /// - En un gasto compartido: lo que pusieron los demás (te lo deben).
    /// - En una devolución de deuda: el monto completo (no es un ingreso
    ///   "ganado", es plata que vuelve).
    /// Es opcional para que las bases existentes migren sin drama.
    var montoAjeno: Double?

    /// Moneda en la que el usuario cargó el gasto, cuando difiere de la
    /// moneda global. `nil` = se cargó en la moneda global (sin conversión).
    /// `monto` siempre queda expresado en la moneda global (ya convertido),
    /// así todos los totales de la app siguen sumando sin cambios.
    var monedaOriginalRaw: String?
    /// Monto tal como lo tecleó el usuario, en `monedaOriginalRaw`.
    var montoOriginal: Double?
    /// Unidades de la moneda global por 1 unidad de la moneda original,
    /// usada para convertir (se guarda para mostrarla y para auditoría).
    var tasaCambio: Double?

    /// Renglones del ticket escaneado, cuando el OCR pudo separarlos.
    /// Es informativo: los totales de la app siguen saliendo de `monto`.
    /// Opcional para que las bases existentes migren sin drama.
    var itemsTicket: [ItemTicket]?
    /// Los renglones tal como los leyó el OCR, si el gasto se cargó
    /// escaneando.
    ///
    /// No se usa para calcular nada: está para poder copiarlos cuando un
    /// ticket se lee mal. Sin esto, un caso que falla solo se puede
    /// reproducir si uno todavía tiene la foto.
    var textoTicket: String?

    init(
        tipo: TipoMovimiento,
        nombre: String,
        categoriaRaw: String,
        monto: Double,
        fecha: Date = .now,
        notas: String = "",
        cuotas: Int = 1,
        cuenta: Cuenta? = nil
    ) {
        self.id = UUID()
        self.tipoRaw = tipo.rawValue
        self.nombre = nombre
        self.categoriaRaw = categoriaRaw
        self.monto = monto
        self.fecha = fecha
        self.notas = notas
        self.cuotas = max(1, cuotas)
        self.cuenta = cuenta
        self.montoAjeno = nil
        self.monedaOriginalRaw = nil
        self.montoOriginal = nil
        self.tasaCambio = nil
        self.itemsTicket = nil
    }

    // MARK: - Tipo y categoría

    var tipo: TipoMovimiento {
        get { TipoMovimiento(rawValue: tipoRaw) ?? .gasto }
        set { tipoRaw = newValue.rawValue }
    }

    var categoria: (any CategoriaInfo)? {
        tipo.categoria(raw: categoriaRaw) ?? CustomCategoryStore.categoria(raw: categoriaRaw, tipo: tipo)
    }

    var nombreCategoria: String { categoria?.nombre ?? categoriaRaw }
    var iconoCategoria: String { categoria?.icono ?? "questionmark.circle" }

    /// Monto con signo: los gastos restan, los ingresos y el cashback suman.
    /// Es el movimiento REAL de plata: se usa para saldos de cuentas.
    var montoConSigno: Double { tipo == .gasto ? -monto : monto }

    // MARK: - Consumo propio (gastos compartidos)

    /// Lo que es realmente tuyo de este movimiento: en un gasto
    /// compartido, tu parte; en una devolución, cero. Es lo que cuentan
    /// las métricas del mes, las categorías y los presupuestos.
    var montoPropio: Double { max(monto - (montoAjeno ?? 0), 0) }

    /// `montoConSigno` pero con el consumo propio: para el balance del mes.
    var montoPropioConSigno: Double { tipo == .gasto ? -montoPropio : montoPropio }

    var esCompartido: Bool { (montoAjeno ?? 0) > 0 }

    // MARK: - Moneda

    /// Moneda en la que se cargó el gasto, si difiere de la global.
    var monedaOriginal: Moneda? {
        guard let monedaOriginalRaw else { return nil }
        return Moneda(rawValue: monedaOriginalRaw)
    }

    /// El gasto se cargó en una moneda distinta a la global.
    var esMonedaExtranjera: Bool { monedaOriginal != nil }

    /// Monto original formateado en su moneda, ej: `US$ 100`.
    var montoOriginalFormateado: String? {
        guard let monedaOriginal, let montoOriginal else { return nil }
        return Formatters.moneda(montoOriginal, moneda: monedaOriginal)
    }

    // MARK: - Cuotas

    var esEnCuotas: Bool { cuotas > 1 }

    var montoCuota: Double { monto / Double(max(1, cuotas)) }

    /// Número de cuota que cae en esa fecha, **sin recortar**: da más que
    /// `cuotas` cuando el plan ya terminó y menos que 1 antes de la
    /// compra. Es lo que hay que mirar para saber si todavía se paga.
    func numeroDeCuota(al referencia: Date = .now) -> Int {
        (Calendar.current.dateComponents([.month], from: fecha, to: referencia).month ?? 0) + 1
    }

    /// Número de cuota para mostrar, acotado a 1...cuotas ("Cuota 3/12").
    func cuotaActual(al referencia: Date = .now) -> Int {
        min(max(numeroDeCuota(al: referencia), 1), cuotas)
    }

    func cuotasRestantes(al referencia: Date = .now) -> Int {
        max(cuotas - cuotaActual(al: referencia), 0)
    }

    /// Monto que todavía falta pagar (cuotas posteriores a la actual).
    func montoPendiente(al referencia: Date = .now) -> Double {
        Double(cuotasRestantes(al: referencia)) * montoCuota
    }

    /// Copia idéntica del movimiento con la fecha actual, para la acción "duplicar".
    func duplicado() -> Movimiento {
        Movimiento(
            tipo: tipo,
            nombre: nombre,
            categoriaRaw: categoriaRaw,
            monto: monto,
            fecha: .now,
            notas: notas,
            cuotas: cuotas,
            cuenta: cuenta
        )
    }
}
