import Foundation
import SwiftData

/// Gastos compartidos: divide un gasto entre varias personas y lleva la
/// cuenta de lo que te deben.
@MainActor
enum DeudasService {

    /// "Juan, Ana,  " → ["Juan", "Ana"].
    static func nombres(desde texto: String) -> [String] {
        texto.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Parte que le toca a cada uno (total dividido entre las personas
    /// nombradas más vos).
    static func parteDeCadaUno(total: Double, nombres: [String]) -> Double {
        guard !nombres.isEmpty, total > 0 else { return 0 }
        return total / Double(nombres.count + 1)
    }

    /// Crea una deuda por persona a partir de un gasto compartido en
    /// partes iguales.
    static func crear(
        conNombres texto: String,
        total: Double,
        detalle: String,
        movimientoID: UUID?,
        en contexto: ModelContext
    ) {
        let personas = nombres(desde: texto)
        let parte = parteDeCadaUno(total: total, nombres: personas)
        guard parte > 0 else { return }
        crear(
            partes: personas.map { ($0, parte) },
            detalle: detalle,
            movimientoID: movimientoID,
            en: contexto
        )
    }

    /// Crea deudas con un monto distinto por persona.
    static func crear(
        partes: [(persona: String, monto: Double)],
        detalle: String,
        movimientoID: UUID?,
        en contexto: ModelContext
    ) {
        for (persona, monto) in partes where monto > 0 {
            contexto.insert(Deuda(
                persona: persona,
                detalle: detalle,
                monto: monto,
                movimientoID: movimientoID
            ))
        }
        try? contexto.save()
    }

    /// Borra las deudas que nacieron de un gasto que se está eliminando:
    /// si el gasto no existió, tampoco lo que te debían por él.
    static func eliminarVinculadas(a movimientoID: UUID, en contexto: ModelContext) {
        let deudas = (try? contexto.fetch(FetchDescriptor<Deuda>())) ?? []
        for deuda in deudas where deuda.movimientoID == movimientoID {
            contexto.delete(deuda)
        }
        try? contexto.save()
    }

    /// Marca la deuda como saldada y, si se pide, registra la devolución
    /// como ingreso para que el balance quede honesto.
    static func saldar(_ deuda: Deuda, registrandoIngreso: Bool, en contexto: ModelContext) {
        deuda.saldada = true
        if registrandoIngreso {
            contexto.insert(Movimiento(
                tipo: .ingreso,
                nombre: String(localized: "Devolución de \(deuda.persona)"),
                categoriaRaw: CategoriaIngreso.otros.rawValue,
                monto: deuda.monto
            ))
        }
        try? contexto.save()
    }
}
