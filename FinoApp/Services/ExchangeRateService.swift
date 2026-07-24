import Foundation

/// Trae cotizaciones de dolarapi.com (gratis, sin API key) para convertir
/// gastos cargados en moneda extranjera a la moneda global de la app.
///
/// Todo se pivotea a través del peso argentino: se guarda cuántos ARS vale
/// una unidad de cada moneda y con eso se convierte cualquier par. La
/// última cotización se cachea en `UserDefaults`, así la conversión sigue
/// funcionando sin conexión (con el último valor conocido).
enum ExchangeRateService {

    /// Cuántos pesos vale una unidad de `moneda` (ARS = 1 por definición).
    /// Devuelve `nil` solo si nunca se pudo traer ni hay cache.
    static func pesosPorUnidad(de moneda: Moneda) async -> Double? {
        if moneda == .ars { return 1 }

        if let fresca = await cotizarRemoto(moneda) {
            guardarCache(fresca, para: moneda)
            return fresca
        }
        return cacheGuardada(para: moneda)
    }

    /// Cuántas unidades de `destino` equivalen a 1 unidad de `origen`.
    /// Ej: origen USD, destino ARS → ~1500.
    static func tasa(de origen: Moneda, a destino: Moneda) async -> Double? {
        guard origen != destino else { return 1 }
        guard let pesosOrigen = await pesosPorUnidad(de: origen),
              let pesosDestino = await pesosPorUnidad(de: destino),
              pesosDestino > 0
        else { return nil }
        return pesosOrigen / pesosDestino
    }

    // MARK: - Red

    private static func cotizarRemoto(_ moneda: Moneda) async -> Double? {
        guard let url = endpoint(para: moneda) else { return nil }
        do {
            let (data, respuesta) = try await URLSession.shared.data(from: url)
            guard let http = respuesta as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let cotizacion = try JSONDecoder().decode(CotizacionDTO.self, from: data)
            return cotizacion.venta > 0 ? cotizacion.venta : nil
        } catch {
            return nil
        }
    }

    private static func endpoint(para moneda: Moneda) -> URL? {
        switch moneda {
        case .ars: nil
        case .usd: URL(string: "https://dolarapi.com/v1/dolares/oficial")
        case .eur: URL(string: "https://dolarapi.com/v1/cotizaciones/eur")
        }
    }

    private struct CotizacionDTO: Decodable {
        let venta: Double
    }

    // MARK: - Cache

    private static func claveCache(_ moneda: Moneda) -> String {
        "cotizacion_\(moneda.rawValue)"
    }

    private static func guardarCache(_ valor: Double, para moneda: Moneda) {
        UserDefaults.standard.set(valor, forKey: claveCache(moneda))
    }

    private static func cacheGuardada(para moneda: Moneda) -> Double? {
        let valor = UserDefaults.standard.double(forKey: claveCache(moneda))
        return valor > 0 ? valor : nil
    }
}
