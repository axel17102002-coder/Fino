import Foundation
import Observation
import SwiftData

/// Estado y validación del formulario de alta/edición de movimientos.
@Observable
final class MovimientoFormViewModel {

    var tipo: TipoMovimiento {
        didSet { if tipo != oldValue { ajustarCategoriaAlCambiarTipo() } }
    }
    var nombre: String
    var categoriaRaw: String
    var montoTexto: String
    var fecha: Date
    var notas: String
    var cuotas: Int
    var cuenta: Cuenta?

    /// Moneda en la que se está cargando el monto. Por defecto, la global.
    var moneda: Moneda
    /// Unidades de la moneda global por 1 unidad de `moneda`. `1` cuando
    /// coinciden. Editable por el usuario (se precarga con la cotización).
    var tasaTexto: String
    /// La cotización se está trayendo de la red.
    var cargandoTasa = false

    private let movimientoEditado: Movimiento?

    init(movimiento: Movimiento? = nil, cuentaPreseleccionada: Cuenta? = nil) {
        movimientoEditado = movimiento
        if let movimiento {
            tipo = movimiento.tipo
            nombre = movimiento.nombre
            categoriaRaw = movimiento.categoriaRaw
            let montoBase = movimiento.montoOriginal ?? movimiento.monto
            montoTexto = montoBase.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", montoBase)
                : String(montoBase).replacingOccurrences(of: ".", with: ",")
            fecha = movimiento.fecha
            notas = movimiento.notas
            cuotas = movimiento.cuotas
            cuenta = movimiento.cuenta
            moneda = movimiento.monedaOriginal ?? Formatters.monedaActual
            tasaTexto = Self.formatearTasa(movimiento.tasaCambio ?? 1)
        } else {
            tipo = .gasto
            nombre = ""
            categoriaRaw = ""
            montoTexto = ""
            fecha = .now
            notas = ""
            cuotas = 1
            cuenta = cuentaPreseleccionada
            moneda = Formatters.monedaActual
            tasaTexto = "1"
        }
    }

    /// Moneda global de la app: contra ella se convierte todo.
    var monedaGlobal: Moneda { Formatters.monedaActual }

    /// El monto se está cargando en una moneda distinta a la global.
    var esMonedaExtranjera: Bool { moneda != monedaGlobal }

    var tasa: Double? { Formatters.parsearMonto(tasaTexto) }

    /// Monto ya convertido a la moneda global (lo que se guarda en `monto`
    /// y suman todos los totales de la app).
    var montoConvertido: Double? {
        guard let monto else { return nil }
        guard esMonedaExtranjera else { return monto }
        guard let tasa, tasa > 0 else { return nil }
        return monto * tasa
    }

    private static func formatearTasa(_ valor: Double) -> String {
        valor.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", valor)
            : String(valor).replacingOccurrences(of: ".", with: ",")
    }

    /// Trae la cotización de la moneda elegida (global por unidad de
    /// `moneda`) y la precarga en el campo editable.
    @MainActor
    func actualizarTasa() async {
        guard esMonedaExtranjera else {
            tasaTexto = "1"
            return
        }
        cargandoTasa = true
        defer { cargandoTasa = false }
        if let tasa = await ExchangeRateService.tasa(de: moneda, a: monedaGlobal) {
            tasaTexto = Self.formatearTasa(tasa)
        }
    }

    var editando: Bool { movimientoEditado != nil }
    var titulo: String { editando ? "Editar movimiento" : "Nuevo movimiento" }

    /// Monto parseado aceptando formato argentino ("1.900.000,50") o plano.
    var monto: Double? {
        Formatters.parsearMonto(montoTexto)
    }

    var esValido: Bool {
        !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (montoConvertido ?? 0) > 0
            && !categoriaRaw.isEmpty
    }

    /// Las cuotas solo aplican a gastos pagados con tarjeta de crédito.
    var permiteCuotas: Bool {
        tipo == .gasto && (cuenta?.esTarjetaCredito ?? false)
    }

    private func ajustarCategoriaAlCambiarTipo() {
        if tipo.categoria(raw: categoriaRaw) == nil {
            categoriaRaw = tipo == .cashback ? CategoriaCashback.cashback.rawValue : ""
        }
        if tipo != .gasto {
            cuotas = 1
        }
    }

    /// Crea o actualiza el movimiento y lo devuelve (`nil` si el
    /// formulario no es válido), para poder vincularle deudas.
    @discardableResult
    func guardar(en contexto: ModelContext) -> Movimiento? {
        guard esValido, let monto, let montoConvertido else { return nil }
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let cuotasFinales = permiteCuotas ? max(1, cuotas) : 1

        let guardado: Movimiento
        if let movimiento = movimientoEditado {
            movimiento.tipo = tipo
            movimiento.nombre = nombreLimpio
            movimiento.categoriaRaw = categoriaRaw
            movimiento.monto = montoConvertido
            movimiento.fecha = fecha
            movimiento.notas = notas
            movimiento.cuotas = cuotasFinales
            movimiento.cuenta = cuenta
            aplicarMoneda(a: movimiento, montoOriginal: monto)
            guardado = movimiento
        } else {
            let nuevo = Movimiento(
                tipo: tipo,
                nombre: nombreLimpio,
                categoriaRaw: categoriaRaw,
                monto: montoConvertido,
                fecha: fecha,
                notas: notas,
                cuotas: cuotasFinales,
                cuenta: cuenta
            )
            aplicarMoneda(a: nuevo, montoOriginal: monto)
            contexto.insert(nuevo)
            guardado = nuevo
        }
        try? contexto.save()
        return guardado
    }

    /// Registra la moneda original solo si difiere de la global; si no,
    /// deja los campos en `nil` (gasto común, sin conversión).
    private func aplicarMoneda(a movimiento: Movimiento, montoOriginal: Double) {
        if esMonedaExtranjera {
            movimiento.monedaOriginalRaw = moneda.rawValue
            movimiento.montoOriginal = montoOriginal
            movimiento.tasaCambio = tasa
        } else {
            movimiento.monedaOriginalRaw = nil
            movimiento.montoOriginal = nil
            movimiento.tasaCambio = nil
        }
    }
}
