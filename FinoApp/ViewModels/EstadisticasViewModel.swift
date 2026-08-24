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
    /// Gasto del mes repartido por medio de pago, de mayor a menor.
    let gastosPorMedioDePago: [TotalPorMedioDePago]
    /// Cashback del mes por tarjeta, para ver cuál rinde más.
    let cashbackPorMedioDePago: [TotalPorMedioDePago]

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
        gastosPorMedioDePago = TotalPorMedioDePago.agrupar(delMes, tipo: .gasto)
        cashbackPorMedioDePago = TotalPorMedioDePago.agrupar(delMes, tipo: .cashback)
    }

    /// El medio con el que más gastaste este mes.
    var medioMasUsado: TotalPorMedioDePago? { gastosPorMedioDePago.first }

    /// La tarjeta que más cashback te devolvió este mes.
    var medioQueMasDevuelve: TotalPorMedioDePago? { cashbackPorMedioDePago.first }

    var topCategorias: [TotalCategoria] {
        Array(gastosPorCategoria.prefix(5))
    }

    var hayDatos: Bool { totalMovimientos > 0 }
}
