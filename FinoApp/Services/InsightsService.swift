import SwiftUI

/// Observación breve sobre las finanzas del usuario, para mostrar en tarjetas.
struct Insight: Identifiable {
    let id = UUID()
    let icono: String
    let color: Color
    let texto: String
}

/// Genera frases del estilo "Este mes gastaste un 18% más que el anterior".
enum InsightsService {

    static func generar(movimientos: [Movimiento], mes: Date = .now) -> [Insight] {
        var insights: [Insight] = []
        let delMes = CalculosService.delMes(movimientos, mes: mes)

        if let variacion = CalculosService.variacionMensual(movimientos, tipo: .gasto, mes: mes) {
            let subio = variacion > 0
            let porcentaje = Formatters.porcentaje(abs(variacion))
            insights.append(Insight(
                icono: subio ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
                color: subio ? .red : .green,
                texto: subio
                    ? String(localized: "Este mes gastaste un \(porcentaje) más que el anterior.")
                    : String(localized: "Este mes gastaste un \(porcentaje) menos que el anterior.")
            ))
        }

        if let top = CalculosService.categoriaTop(delMes, tipo: .gasto) {
            let totalGastos = CalculosService.total(delMes, tipo: .gasto)
            if totalGastos > 0 {
                let fraccion = top.total / totalGastos
                insights.append(Insight(
                    icono: top.categoria.icono,
                    color: top.categoria.color,
                    texto: String(localized: "El \(Formatters.porcentaje(fraccion)) de tus gastos fueron en \(top.categoria.nombre.lowercased()).")
                ))
            }
        }

        if let mayor = CalculosService.mayorGasto(movimientos, mes: mes) {
            insights.append(Insight(
                icono: "flame.fill",
                color: .orange,
                texto: String(localized: "Tu mayor gasto fue \(mayor.nombre) (\(mayor.monto.enMoneda)) el \(mayor.fecha.diaYMes).")
            ))
        }

        if let dia = CalculosService.diaSemanaConMasGasto(movimientos) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            let simbolos = formatter.weekdaySymbols ?? []
            if dia - 1 < simbolos.count {
                insights.append(Insight(
                    icono: "calendar",
                    color: .indigo,
                    texto: String(localized: "Los \(simbolos[dia - 1]) son tu día de mayor consumo.")
                ))
            }
        }

        let suscripciones = delMes
            .filter { $0.tipo == .gasto && $0.categoriaRaw == CategoriaGasto.suscripciones.rawValue }
            .reduce(0) { $0 + $1.monto }
        if suscripciones > 0 {
            insights.append(Insight(
                icono: "arrow.triangle.2.circlepath",
                color: .purple,
                texto: String(localized: "Gastás \(suscripciones.enMoneda) por mes en suscripciones.")
            ))
        }

        let cashback = CalculosService.total(delMes, tipo: .cashback)
        if cashback > 0 {
            insights.append(Insight(
                icono: "percent",
                color: .orange,
                texto: String(localized: "Recuperaste \(cashback.enMoneda) en cashback este mes.")
            ))
        }

        return insights
    }
}
