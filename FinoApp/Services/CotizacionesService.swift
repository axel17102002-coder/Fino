import Foundation

/// Trae el precio de las tenencias que se siguen por ticker: acciones de
/// Estados Unidos y criptomonedas.
///
/// Dos fuentes gratuitas y sin clave, elegidas por eso mismo: una API con
/// registro habría atado la app a una cuenta y a un límite que no
/// controlamos.
///
/// - Cripto: la API pública de Binance, por símbolo contra USDT. No hace
///   falta traducir el ticker a un identificador propio como sí piden
///   otras fuentes.
/// - Acciones: el endpoint público de gráficos de Yahoo Finance. Probé
///   antes con Stooq, que publica un CSV muy cómodo de leer, pero
///   responde una página de error salvo que vayas con sesión de
///   navegador.
///
/// Si una falla, la tenencia se queda con el precio que ya tenía. Nunca se
/// borra un precio cargado a mano por no haber podido consultarlo: es
/// preferible un número viejo y visible a un cero.
enum CotizacionesService {

    /// Precio en dólares de un ticker, o `nil` si no se pudo obtener.
    static func precio(de ticker: String, tipo: TipoInversion) async -> Double? {
        let limpio = ticker.trimmingCharacters(in: .whitespaces).uppercased()
        guard !limpio.isEmpty else { return nil }

        return switch tipo {
        case .cripto: await precioCripto(limpio)
        case .accion: await precioAccion(limpio)
        default: nil
        }
    }

    /// Actualiza el precio de las tenencias que se siguen por ticker y
    /// devuelve los nombres de las que no se pudieron consultar.
    ///
    /// Devuelve cuáles fallaron y no cuántas: con un número, un ticker mal
    /// escrito obliga a adivinar cuál de todas es. Con el nombre, se ve.
    ///
    /// Las que se cargan con capital —plazo fijo, cuenta remunerada,
    /// divisa— no se tocan: no tienen cotización que buscar.
    @discardableResult
    static func actualizar(_ tenencias: [Inversion]) async -> [String] {
        var fallidas: [String] = []
        for tenencia in tenencias where tenencia.tipo.usaTicker {
            guard let precio = await precio(de: tenencia.nombre, tipo: tenencia.tipo) else {
                fallidas.append(tenencia.nombre)
                continue
            }
            tenencia.precio = precio
            tenencia.precioActualizado = .now
        }
        return fallidas
    }

    // MARK: - Cripto

    private static func precioCripto(_ ticker: String) async -> Double? {
        // Binance cotiza contra USDT, que a estos fines vale un dólar.
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=\(ticker)USDT") else {
            return nil
        }
        guard let data = await traer(url) else { return nil }
        guard let dto = try? JSONDecoder().decode(PrecioBinance.self, from: data) else {
            return nil
        }
        return Double(dto.price).flatMap { $0 > 0 ? $0 : nil }
    }

    private struct PrecioBinance: Decodable {
        let price: String
    }

    // MARK: - Acciones

    private static func precioAccion(_ ticker: String) async -> Double? {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=1d") else {
            return nil
        }
        guard let data = await traer(url) else { return nil }
        return precioDeRespuestaYahoo(data)
    }

    /// Saca el precio de la respuesta de Yahoo. Separado para poder
    /// probarlo sin red: el formato es lo único que se puede romper solo.
    ///
    /// Solo acepta papeles cotizados en dólares. Un papel en euros
    /// devolvería un número que no es el que la cartera espera, y
    /// guardarlo como si fueran dólares daría un total inflado sin que
    /// nada lo delate.
    static func precioDeRespuestaYahoo(_ data: Data) -> Double? {
        guard let raiz = try? JSONDecoder().decode(RespuestaYahoo.self, from: data),
              let meta = raiz.chart.result?.first?.meta,
              meta.currency == "USD",
              let precio = meta.regularMarketPrice,
              precio > 0
        else { return nil }
        return precio
    }

    private struct RespuestaYahoo: Decodable {
        let chart: Chart

        struct Chart: Decodable {
            let result: [Resultado]?
        }

        struct Resultado: Decodable {
            let meta: Meta
        }

        struct Meta: Decodable {
            let currency: String?
            let regularMarketPrice: Double?
        }
    }

    // MARK: - Red

    private static func traer(_ url: URL) async -> Data? {
        do {
            // Sin User-Agent, Yahoo contesta "Too Many Requests" desde el
            // primer pedido.
            var pedido = URLRequest(url: url)
            pedido.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, respuesta) = try await URLSession.shared.data(for: pedido)
            guard let http = respuesta as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}
