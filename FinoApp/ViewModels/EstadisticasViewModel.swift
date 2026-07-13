import Foundation

/// Prepara las series y los indicadores de la pantalla de Estadísticas.
struct EstadisticasViewModel {

    let series: [PuntoMensual]
    let gastosPorCategoria: [TotalCategoria]
    let insights: [Insight]
    let totalMovimientos: Int
    let promedioDiarioGastos: Double
    let promedioDiarioIngresos: Double
    let categoriaTopGasto: TotalCategoria?
    let categoriaTopIngreso: TotalCategoria?

    init(movimientos: [Movimiento], meses: Int = 6, mes: Date = .now) {
        series = CalculosService.seriesMensuales(movimientos, meses: meses)
        let delMes = CalculosService.delMes(movimientos, mes: mes)
        gastosPorCategoria = CalculosService.totalesPorCategoria(delMes, tipo: .gasto)
        insights = InsightsService.generar(movimientos: movimientos, mes: mes)
        totalMovimientos = movimientos.count
        promedioDiarioGastos = CalculosService.promedioDiario(
            total: CalculosService.total(delMes, tipo: .gasto), mes: mes
        )
        promedioDiarioIngresos = CalculosService.promedioDiario(
            total: CalculosService.total(delMes, tipo: .ingreso), mes: mes
        )
        categoriaTopGasto = CalculosService.categoriaTop(delMes, tipo: .gasto)
        categoriaTopIngreso = CalculosService.categoriaTop(delMes, tipo: .ingreso)
    }

    var topCategorias: [TotalCategoria] {
        Array(gastosPorCategoria.prefix(5))
    }

    var hayDatos: Bool { totalMovimientos > 0 }
}
