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

    private let movimientoEditado: Movimiento?

    init(movimiento: Movimiento? = nil) {
        movimientoEditado = movimiento
        if let movimiento {
            tipo = movimiento.tipo
            nombre = movimiento.nombre
            categoriaRaw = movimiento.categoriaRaw
            montoTexto = movimiento.monto.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", movimiento.monto)
                : String(movimiento.monto).replacingOccurrences(of: ".", with: ",")
            fecha = movimiento.fecha
            notas = movimiento.notas
            cuotas = movimiento.cuotas
            cuenta = movimiento.cuenta
        } else {
            tipo = .gasto
            nombre = ""
            categoriaRaw = ""
            montoTexto = ""
            fecha = .now
            notas = ""
            cuotas = 1
            cuenta = nil
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
            && (monto ?? 0) > 0
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

    /// Crea o actualiza el movimiento. Devuelve `true` si se guardó.
    @discardableResult
    func guardar(en contexto: ModelContext) -> Bool {
        guard esValido, let monto else { return false }
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let cuotasFinales = permiteCuotas ? max(1, cuotas) : 1

        if let movimiento = movimientoEditado {
            movimiento.tipo = tipo
            movimiento.nombre = nombreLimpio
            movimiento.categoriaRaw = categoriaRaw
            movimiento.monto = monto
            movimiento.fecha = fecha
            movimiento.notas = notas
            movimiento.cuotas = cuotasFinales
            movimiento.cuenta = cuenta
        } else {
            contexto.insert(Movimiento(
                tipo: tipo,
                nombre: nombreLimpio,
                categoriaRaw: categoriaRaw,
                monto: monto,
                fecha: fecha,
                notas: notas,
                cuotas: cuotasFinales,
                cuenta: cuenta
            ))
        }
        try? contexto.save()
        return true
    }
}
