import Foundation

/// Limpia los nombres de comercio que llegan de Apple Pay o del OCR de
/// tickets: "MERPAGO*KIOSCO SA 123" → "Kiosco".
enum NombreComercio {

    /// Sufijos societarios que no aportan nada al nombre.
    private static let sufijosLegales: Set<String> = [
        "SA", "S.A.", "S.A", "SRL", "S.R.L.", "S.R.L", "SAS", "S.A.S.",
        "SACI", "SAIC", "CIA", "CIA.", "LLC", "INC", "INC.", "LTD", "LTDA"
    ]

    static func limpiar(_ crudo: String) -> String {
        let original = crudo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return original }
        var texto = original

        // Prefijos de agregadores de pago ("MERPAGO*", "PAYPAL *"):
        // el comercio real viene después del asterisco.
        if let ultimoAsterisco = texto.lastIndex(of: "*") {
            let resto = String(texto[texto.index(after: ultimoAsterisco)...])
                .trimmingCharacters(in: .whitespaces)
            if resto.filter(\.isLetter).count >= 3 {
                texto = resto
            }
        }

        var palabras = texto.split(separator: " ").map(String.init)

        // "SUCURSAL 45" y todo lo que siga es ruido.
        if let indice = palabras.firstIndex(where: {
            ["SUC", "SUC.", "SUCURSAL"].contains($0.uppercased())
        }) {
            palabras = Array(palabras[..<indice])
        }

        palabras = palabras.filter { palabra in
            let mayusculas = palabra.uppercased()
            if sufijosLegales.contains(mayusculas) { return false }
            // Números de local o terminal ("123").
            if palabra.allSatisfy(\.isNumber) { return false }
            // Siglas con puntos ("C.I.C.S.A.").
            if palabra.contains("."),
               palabra.split(separator: ".").allSatisfy({ $0.count == 1 }) {
                return false
            }
            return true
        }

        var resultado = palabras.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard resultado.filter(\.isLetter).count >= 2 else {
            return original
        }

        // Si vino gritado en mayúsculas, se pasa a "Tipo Título".
        if resultado == resultado.uppercased() {
            resultado = resultado.capitalized
        }
        return resultado
    }
}
