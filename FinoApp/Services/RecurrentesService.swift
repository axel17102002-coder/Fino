import Foundation
import SwiftData

/// Genera los movimientos que corresponden a las plantillas recurrentes.
/// Se ejecuta al abrir la app: crea los movimientos vencidos desde la
/// última generación (si la app estuvo cerrada meses, los crea todos).
@MainActor
enum RecurrentesService {

    static func generarPendientes(en contexto: ModelContext) async {
        guard let plantillas = try? contexto.fetch(FetchDescriptor<MovimientoRecurrente>()) else {
            return
        }
        var huboCambios = false

        for plantilla in plantillas where plantilla.activo {
            // Una sola cotización por plantilla, no una por movimiento
            // atrasado: si la app estuvo cerrada medio año, se generan
            // todos con la cotización de hoy igual, porque las de esos
            // meses ya no se pueden consultar.
            let tasa = plantilla.necesitaConversion
                ? await ExchangeRateService.tasa(de: plantilla.moneda, a: Formatters.monedaActual)
                : nil

            var referencia = plantilla.ultimaGenerada ?? plantilla.creado
            while let proxima = proximaOcurrencia(dia: plantilla.diaDelMes, despuesDe: referencia),
                  proxima <= .now {
                contexto.insert(movimiento(de: plantilla, fecha: proxima, tasa: tasa))
                plantilla.ultimaGenerada = proxima
                referencia = proxima
                huboCambios = true
            }
        }

        if huboCambios {
            try? contexto.save()
        }
    }

    /// Arma el movimiento de una ocurrencia, convirtiendo si la plantilla
    /// está en otra moneda.
    ///
    /// Sin cotización —ni de red ni de cache— se genera igual con el monto
    /// tal cual: es preferible un gasto con el número sin convertir, que
    /// se ve y se corrige, a que el mes no quede registrado.
    private static func movimiento(
        de plantilla: MovimientoRecurrente,
        fecha: Date,
        tasa: Double?
    ) -> Movimiento {
        let convertido = tasa.map { plantilla.monto * $0 } ?? plantilla.monto
        let nuevo = Movimiento(
            tipo: plantilla.tipo,
            nombre: plantilla.nombre,
            categoriaRaw: plantilla.categoriaRaw,
            monto: convertido,
            fecha: fecha,
            notas: String(localized: "Generado automáticamente"),
            cuenta: plantilla.cuenta
        )
        if let tasa {
            nuevo.monedaOriginalRaw = plantilla.moneda.rawValue
            nuevo.montoOriginal = plantilla.monto
            nuevo.tasaCambio = tasa
        }
        return nuevo
    }

    /// Próxima ocurrencia de un día del mes estrictamente después de la
    /// referencia. En meses cortos usa el último día del mes.
    private static func proximaOcurrencia(dia: Int, despuesDe referencia: Date) -> Date? {
        guard (1...31).contains(dia) else { return nil }
        let calendario = Calendar.current
        for offsetMes in 0...2 {
            guard let mes = calendario.date(byAdding: .month, value: offsetMes, to: referencia),
                  let diasDelMes = calendario.range(of: .day, in: .month, for: mes)?.count
            else { continue }
            var componentes = calendario.dateComponents([.year, .month], from: mes)
            componentes.day = min(dia, diasDelMes)
            if let fecha = calendario.date(from: componentes), fecha > referencia {
                return fecha
            }
        }
        return nil
    }
}
