import Foundation
import SwiftData
import SwiftUI

/// En qué está puesta la plata. Define cómo se carga y de qué gama de
/// color es en el donut.
enum TipoInversion: String, CaseIterable, Codable, Identifiable {
    case accion
    case cripto
    case plazoFijo
    case cuentaRemunerada
    case otro

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .accion: String(localized: "Acciones")
        case .cripto: String(localized: "Cripto")
        case .plazoFijo: String(localized: "Plazo fijo")
        case .cuentaRemunerada: String(localized: "Cuenta remunerada")
        case .otro: String(localized: "Otras")
        }
    }

    var icono: String {
        switch self {
        case .accion: "chart.line.uptrend.xyaxis"
        case .cripto: "bitcoinsign.circle.fill"
        case .plazoFijo: "lock.circle.fill"
        case .cuentaRemunerada: "percent"
        case .otro: "circle.dashed"
        }
    }

    /// Se carga con cantidad y cotización (una acción, una cripto) en vez
    /// de con un capital.
    var usaTicker: Bool {
        self == .accion || self == .cripto
    }

    /// Color base de la clase. Las tenencias de una misma clase salen en
    /// tonos de este color, así el donut se lee como bloques aunque tenga
    /// doce porciones: un arco azul para las acciones, uno naranja para
    /// las criptos.
    var color: Color {
        switch self {
        case .accion: .blue
        case .cripto: .orange
        case .plazoFijo: .green
        case .cuentaRemunerada: .purple
        case .otro: .gray
        }
    }
}

/// Una tenencia: qué es, cuánto hay y dónde está.
///
/// No guarda precio de compra ni fecha: la idea es tener a mano lo que
/// tenés, no seguir cuánto ganaste o perdiste. Eso simplifica el modelo a
/// "cuánto vale hoy y dónde".
@Model
final class Inversion {

    @Attribute(.unique) var id: UUID
    /// Ticker o nombre: "AAPL", "BTC", "Plazo fijo Galicia".
    var nombre: String
    var tipoRaw: String
    /// Broker, exchange o banco donde está.
    var donde: String
    var monedaRaw: String

    /// Cantidad y cotización, para las que se cargan con ticker. El día
    /// que una API traiga los precios, solo cambia quién llena `precio`.
    var cantidad: Double?
    var precio: Double?

    /// Capital, para plazos fijos y cuentas remuneradas, que no tienen
    /// cantidad ni cotización.
    var monto: Double?

    /// Informativos: no entran en ninguna cuenta, sirven para avisar que
    /// un plazo fijo está por vencer.
    var tasaAnual: Double?
    var vencimiento: Date?

    var orden: Int

    init(
        nombre: String,
        tipo: TipoInversion,
        donde: String = "",
        moneda: Moneda = .usd,
        cantidad: Double? = nil,
        precio: Double? = nil,
        monto: Double? = nil,
        tasaAnual: Double? = nil,
        vencimiento: Date? = nil,
        orden: Int = 0
    ) {
        self.id = UUID()
        self.nombre = nombre
        self.tipoRaw = tipo.rawValue
        self.donde = donde
        self.monedaRaw = moneda.rawValue
        self.cantidad = cantidad
        self.precio = precio
        self.monto = monto
        self.tasaAnual = tasaAnual
        self.vencimiento = vencimiento
        self.orden = orden
    }

    var tipo: TipoInversion {
        TipoInversion(rawValue: tipoRaw) ?? .otro
    }

    var moneda: Moneda {
        Moneda(rawValue: monedaRaw) ?? .usd
    }

    /// Cuánto vale, en su propia moneda.
    var valor: Double {
        if let cantidad, let precio { return cantidad * precio }
        return monto ?? 0
    }

    /// Días que faltan para el vencimiento, si lo tiene y no pasó.
    var diasParaVencer: Int? {
        guard let vencimiento else { return nil }
        let dias = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: .now), to: vencimiento
        ).day
        guard let dias, dias >= 0 else { return nil }
        return dias
    }
}
