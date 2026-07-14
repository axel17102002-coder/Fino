import SwiftUI

/// Claves de las preferencias persistidas en `UserDefaults` / `@AppStorage`.
enum Preferencias {
    static let claveMoneda = "moneda"
    static let claveTema = "tema"
    static let claveDatosDemoCargados = "datosDemoCargados"
    static let claveNombre = "nombreUsuario"
    static let claveOnboardingCompletado = "onboardingCompletado"
    static let claveBloqueoBiometrico = "bloqueoBiometrico"
    static let claveRecordatorioBackup = "recordatorioBackup"
    static let claveDiaInicioMes = "diaInicioMes"
    static let claveRedondeoActivado = "redondeoActivado"
    static let claveRedondeoObjetivoID = "redondeoObjetivoID"
    static let claveRedondeoPaso = "redondeoPaso"
    static let claveTotalRedondeado = "totalRedondeado"
}

// MARK: - Moneda

enum Moneda: String, CaseIterable, Identifiable {
    case ars = "ARS"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .ars: String(localized: "Peso argentino")
        case .usd: String(localized: "Dólar estadounidense")
        case .eur: String(localized: "Euro")
        }
    }

    var simbolo: String {
        switch self {
        case .ars: "$"
        case .usd: "US$"
        case .eur: "€"
        }
    }

    var decimales: Int {
        switch self {
        case .ars: 0
        case .usd, .eur: 2
        }
    }
}

// MARK: - Tema

enum TemaApp: String, CaseIterable, Identifiable {
    case automatico
    case claro
    case oscuro

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .automatico: String(localized: "Automático")
        case .claro: String(localized: "Claro")
        case .oscuro: String(localized: "Oscuro")
        }
    }

    var icono: String {
        switch self {
        case .automatico: "circle.lefthalf.filled"
        case .claro: "sun.max.fill"
        case .oscuro: "moon.fill"
        }
    }

    var esquema: ColorScheme? {
        switch self {
        case .automatico: nil
        case .claro: .light
        case .oscuro: .dark
        }
    }
}
