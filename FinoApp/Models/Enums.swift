import SwiftUI

// MARK: - Tipo de movimiento

enum TipoMovimiento: String, CaseIterable, Codable, Identifiable {
    case gasto
    case ingreso
    case cashback

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .gasto: String(localized: "Gasto")
        case .ingreso: String(localized: "Ingreso")
        case .cashback: String(localized: "Cashback")
        }
    }

    var nombrePlural: String {
        switch self {
        case .gasto: String(localized: "Gastos")
        case .ingreso: String(localized: "Ingresos")
        case .cashback: String(localized: "Cashback")
        }
    }

    var icono: String {
        switch self {
        case .gasto: "arrow.up.right.circle.fill"
        case .ingreso: "arrow.down.left.circle.fill"
        case .cashback: "percent"
        }
    }

    var color: Color {
        switch self {
        case .gasto: .red
        case .ingreso: .green
        case .cashback: .orange
        }
    }

    /// Categorías disponibles para este tipo de movimiento.
    var categorias: [any CategoriaInfo] {
        switch self {
        case .gasto: CategoriaGasto.allCases
        case .ingreso: CategoriaIngreso.allCases
        case .cashback: CategoriaCashback.allCases
        }
    }

    func categoria(raw: String) -> (any CategoriaInfo)? {
        categorias.first { $0.rawValue == raw }
    }

    var categoriaPorDefecto: any CategoriaInfo {
        switch self {
        case .gasto: CategoriaGasto.otros
        case .ingreso: CategoriaIngreso.otros
        case .cashback: CategoriaCashback.cashback
        }
    }
}

// MARK: - Categorías

/// Abstracción común para las categorías de los tres tipos de movimiento.
protocol CategoriaInfo {
    var rawValue: String { get }
    var nombre: String { get }
    var icono: String { get }
    var color: Color { get }
}

/// Envoltorio `Identifiable` para usar categorías existenciales en `ForEach`.
struct CategoriaEnvuelta: Identifiable {
    let base: any CategoriaInfo
    var id: String { base.rawValue }
}

enum CategoriaGasto: String, CaseIterable, Codable, Identifiable, CategoriaInfo {
    case comida, supermercado, transporte, hogar, salud, ocio, ropa
    case suscripciones, viajes, educacion, servicios, mascotas, regalos
    case comprasOnline, otros

    var id: String { rawValue }

    // El usuario puede pisar nombre, ícono y color desde el editor de
    // categorías; los valores de fábrica quedan como respaldo.

    var nombre: String {
        CustomCategoryStore.ajuste(para: rawValue, tipo: .gasto)?.nombre ?? nombreDeFabrica
    }

    var icono: String {
        CustomCategoryStore.ajuste(para: rawValue, tipo: .gasto)?.icono ?? iconoDeFabrica
    }

    var color: Color {
        if let hex = CustomCategoryStore.ajuste(para: rawValue, tipo: .gasto)?.colorHex {
            return Color(hex: hex)
        }
        return colorDeFabrica
    }

    private var nombreDeFabrica: String {
        switch self {
        case .comida: String(localized: "Comida")
        case .supermercado: String(localized: "Supermercado")
        case .transporte: String(localized: "Transporte")
        case .hogar: String(localized: "Hogar")
        case .salud: String(localized: "Salud")
        case .ocio: String(localized: "Ocio")
        case .ropa: String(localized: "Ropa")
        case .suscripciones: String(localized: "Suscripciones")
        case .viajes: String(localized: "Viajes")
        case .educacion: String(localized: "Educación")
        case .servicios: String(localized: "Servicios")
        case .mascotas: String(localized: "Mascotas")
        case .regalos: String(localized: "Regalos")
        case .comprasOnline: String(localized: "Compras Online")
        case .otros: String(localized: "Otros")
        }
    }

    private var iconoDeFabrica: String {
        switch self {
        case .comida: "fork.knife"
        case .supermercado: "cart.fill"
        case .transporte: "bus.fill"
        case .hogar: "house.fill"
        case .salud: "cross.case.fill"
        case .ocio: "popcorn.fill"
        case .ropa: "tshirt.fill"
        case .suscripciones: "arrow.triangle.2.circlepath"
        case .viajes: "airplane"
        case .educacion: "graduationcap.fill"
        case .servicios: "bolt.fill"
        case .mascotas: "pawprint.fill"
        case .regalos: "gift.fill"
        case .comprasOnline: "shippingbox.fill"
        case .otros: "ellipsis.circle.fill"
        }
    }

    private var colorDeFabrica: Color {
        switch self {
        case .comida: .orange
        case .supermercado: .green
        case .transporte: .blue
        case .hogar: .brown
        case .salud: .red
        case .ocio: .purple
        case .ropa: .pink
        case .suscripciones: .indigo
        case .viajes: .teal
        case .educacion: .cyan
        case .servicios: .yellow
        case .mascotas: .mint
        case .regalos: Color(hex: "E11D48")
        case .comprasOnline: Color(hex: "F59E0B")
        case .otros: .gray
        }
    }
}

enum CategoriaIngreso: String, CaseIterable, Codable, Identifiable, CategoriaInfo {
    case sueldo, alquiler, inversiones, freelance, regalo, otros

    var id: String { rawValue }

    var nombre: String {
        CustomCategoryStore.ajuste(para: rawValue, tipo: .ingreso)?.nombre ?? nombreDeFabrica
    }

    var icono: String {
        CustomCategoryStore.ajuste(para: rawValue, tipo: .ingreso)?.icono ?? iconoDeFabrica
    }

    var color: Color {
        if let hex = CustomCategoryStore.ajuste(para: rawValue, tipo: .ingreso)?.colorHex {
            return Color(hex: hex)
        }
        return colorDeFabrica
    }

    private var nombreDeFabrica: String {
        switch self {
        case .sueldo: String(localized: "Sueldo")
        case .alquiler: String(localized: "Alquiler")
        case .inversiones: String(localized: "Inversiones")
        case .freelance: String(localized: "Freelance")
        case .regalo: String(localized: "Regalo")
        case .otros: String(localized: "Otros")
        }
    }

    private var iconoDeFabrica: String {
        switch self {
        case .sueldo: "banknote.fill"
        case .alquiler: "building.2.fill"
        case .inversiones: "chart.line.uptrend.xyaxis"
        case .freelance: "laptopcomputer"
        case .regalo: "gift.fill"
        case .otros: "ellipsis.circle.fill"
        }
    }

    private var colorDeFabrica: Color {
        switch self {
        case .sueldo: .green
        case .alquiler: .teal
        case .inversiones: .indigo
        case .freelance: .blue
        case .regalo: .pink
        case .otros: .gray
        }
    }
}

enum CategoriaCashback: String, CaseIterable, Codable, Identifiable, CategoriaInfo {
    case cashback

    var id: String { rawValue }

    var nombre: String {
        CustomCategoryStore.ajuste(para: rawValue, tipo: .cashback)?.nombre ?? String(localized: "Cashback")
    }

    var icono: String {
        CustomCategoryStore.ajuste(para: rawValue, tipo: .cashback)?.icono ?? "arrow.counterclockwise.circle.fill"
    }

    var color: Color {
        if let hex = CustomCategoryStore.ajuste(para: rawValue, tipo: .cashback)?.colorHex {
            return Color(hex: hex)
        }
        return .orange
    }
}

// MARK: - Tipo de cuenta

enum TipoCuenta: String, CaseIterable, Codable, Identifiable {
    case efectivo
    case cuentaBancaria
    case billeteraVirtual
    case tarjetaCredito

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .efectivo: String(localized: "Efectivo")
        case .cuentaBancaria: String(localized: "Cuenta bancaria")
        case .billeteraVirtual: String(localized: "Billetera virtual")
        case .tarjetaCredito: String(localized: "Tarjeta de crédito")
        }
    }

    var icono: String {
        switch self {
        case .efectivo: "banknote.fill"
        case .cuentaBancaria: "building.columns.fill"
        case .billeteraVirtual: "wallet.pass.fill"
        case .tarjetaCredito: "creditcard.fill"
        }
    }
}
