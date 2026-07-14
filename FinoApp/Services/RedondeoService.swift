import Foundation
import SwiftData

/// Redondeo a metas: cada gasto se redondea al paso elegido y el vuelto
/// virtual se aporta al objetivo de ahorro configurado.
/// Ejemplo con paso $1.000: gasto de $4.320 → $680 van a la meta.
@MainActor
enum RedondeoService {

    /// Vuelto virtual de un gasto (0 si el monto ya es redondo).
    static func vuelto(para monto: Double, paso: Double) -> Double {
        guard monto > 0, paso > 0 else { return 0 }
        let resto = monto.truncatingRemainder(dividingBy: paso)
        guard resto > 0.009 else { return 0 }
        return ((paso - resto) * 100).rounded() / 100
    }

    /// Aplica el redondeo de un gasto nuevo al objetivo configurado.
    static func aplicar(aGastoDe monto: Double, en contexto: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Preferencias.claveRedondeoActivado),
              let idTexto = defaults.string(forKey: Preferencias.claveRedondeoObjetivoID),
              let id = UUID(uuidString: idTexto)
        else { return }

        let paso = defaults.double(forKey: Preferencias.claveRedondeoPaso)
        let aporte = vuelto(para: monto, paso: paso > 0 ? paso : 1000)
        guard aporte > 0 else { return }

        let objetivos = (try? contexto.fetch(FetchDescriptor<ObjetivoAhorro>())) ?? []
        guard let objetivo = objetivos.first(where: { $0.id == id }) else { return }

        objetivo.ahorrado += aporte
        defaults.set(
            defaults.double(forKey: Preferencias.claveTotalRedondeado) + aporte,
            forKey: Preferencias.claveTotalRedondeado
        )
        try? contexto.save()
    }
}
