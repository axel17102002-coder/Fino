import Foundation
import SwiftData

/// Genera los movimientos que corresponden a las plantillas recurrentes.
/// Se ejecuta al abrir la app: crea los movimientos vencidos desde la
/// última generación (si la app estuvo cerrada meses, los crea todos).
@MainActor
enum RecurrentesService {

    static func generarPendientes(en contexto: ModelContext) {
        guard let plantillas = try? contexto.fetch(FetchDescriptor<MovimientoRecurrente>()) else {
            return
        }
        var huboCambios = false

        for plantilla in plantillas where plantilla.activo {
            var referencia = plantilla.ultimaGenerada ?? plantilla.creado
            while let proxima = proximaOcurrencia(dia: plantilla.diaDelMes, despuesDe: referencia),
                  proxima <= .now {
                contexto.insert(Movimiento(
                    tipo: plantilla.tipo,
                    nombre: plantilla.nombre,
                    categoriaRaw: plantilla.categoriaRaw,
                    monto: plantilla.monto,
                    fecha: proxima,
                    notas: "Generado automáticamente",
                    cuenta: plantilla.cuenta
                ))
                plantilla.ultimaGenerada = proxima
                referencia = proxima
                huboCambios = true
            }
        }

        if huboCambios {
            try? contexto.save()
        }
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
