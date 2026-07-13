import Foundation

/// Prepara todos los datos que muestra el Dashboard.
struct DashboardViewModel {

    let movimientosDelMes: [Movimiento]
    let totalGastos: Double
    let totalIngresos: Double
    let totalCashback: Double
    let balance: Double
    let ultimosMovimientos: [Movimiento]
    let variacionGastos: Double?
    private let fraccionGastos: Double?
    private let fraccionCashback: Double?

    init(movimientos: [Movimiento], mes: Date = .now) {
        let delMes = CalculosService.delMes(movimientos, mes: mes)
        movimientosDelMes = delMes
        totalGastos = CalculosService.total(delMes, tipo: .gasto)
        totalIngresos = CalculosService.total(delMes, tipo: .ingreso)
        totalCashback = CalculosService.total(delMes, tipo: .cashback)
        balance = CalculosService.balance(delMes)
        ultimosMovimientos = Array(movimientos.sorted { $0.fecha > $1.fecha }.prefix(5))
        variacionGastos = CalculosService.variacionMensual(movimientos, tipo: .gasto, mes: mes)
        fraccionGastos = CalculosService.fraccionGastosSobreIngresos(delMes)
        fraccionCashback = CalculosService.fraccionCashbackSobreGastos(delMes)
    }

    var hayDatosEnElMes: Bool {
        totalGastos > 0 || totalIngresos > 0 || totalCashback > 0
    }

    /// Secciones del gráfico de dona: los gastos del mes divididos por
    /// categoría. Ingresos y cashback no forman parte del gráfico.
    var segmentosDonut: [SegmentoDonut] {
        CalculosService
            .totalesPorCategoria(movimientosDelMes, tipo: .gasto)
            .map {
                SegmentoDonut(
                    id: $0.id,
                    nombre: $0.categoria.nombre,
                    color: $0.categoria.color,
                    monto: $0.total
                )
            }
    }

    func monto(para tipo: TipoMovimiento) -> Double {
        switch tipo {
        case .gasto: totalGastos
        case .ingreso: totalIngresos
        case .cashback: totalCashback
        }
    }

    /// "76% de tus ingresos", para la tarjeta de gastos.
    var subtituloGastos: String? {
        fraccionGastos.map { "\(Formatters.porcentaje($0)) de tus ingresos" }
    }

    /// "2,5% de tus gastos", para la tarjeta de cashback.
    var subtituloCashback: String? {
        guard let fraccionCashback else { return nil }
        return String(format: "%.1f%% de tus gastos", fraccionCashback * 100)
            .replacingOccurrences(of: ".", with: ",")
    }
}
