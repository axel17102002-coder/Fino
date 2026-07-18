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

    // MARK: - Cuotas

    var esEnCuotas: Bool { cuotas > 1 }

    var montoCuota: Double { monto / Double(max(1, cuotas)) }

    /// Número de cuota que corresponde pagar en la fecha de referencia (1...cuotas).
    func cuotaActual(al referencia: Date = .now) -> Int {
        let meses = Calendar.current.dateComponents([.month], from: fecha, to: referencia).month ?? 0
        return min(max(meses + 1, 1), cuotas)
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
