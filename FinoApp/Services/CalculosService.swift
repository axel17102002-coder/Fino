import Foundation

/// Total de una categoría, listo para usar en listas y gráficos.
struct TotalCategoria: Identifiable {
    let categoria: any CategoriaInfo
    let total: Double
    var id: String { categoria.rawValue }
}

/// Totales de un mes calendario, para las series históricas.
struct PuntoMensual: Identifiable {
    let mes: Date
    let ingresos: Double
    let gastos: Double
    let cashback: Double

    var balance: Double { ingresos - gastos + cashback }
    var id: Date { mes }
}

/// Lógica de negocio pura: todos los cálculos financieros de la app.
enum CalculosService {

    // MARK: - Período financiero

    /// Día del mes en que arranca el "mes financiero" del usuario (1 a 31).
    /// Se configura en Configuración; por defecto es el 1 (mes calendario).
    static var diaInicioMes: Int {
        let dia = UserDefaults.standard.integer(forKey: Preferencias.claveDiaInicioMes)
        return (1...31).contains(dia) ? dia : 1
    }

    /// Comienzo del período financiero que contiene a la fecha dada.
    /// Si el mes no llega al día configurado (ej: 31 en febrero), se usa
    /// el último día de ese mes.
    static func inicioPeriodo(conteniendo fecha: Date = .now) -> Date {
        let calendario = Calendar.current
        let dia = diaInicioMes

        func inicioEnMes(de referencia: Date) -> Date? {
            var componentes = calendario.dateComponents([.year, .month], from: referencia)
            guard let mes = calendario.date(from: componentes),
                  let diasDelMes = calendario.range(of: .day, in: .month, for: mes)?.count
            else { return nil }
            componentes.day = min(dia, diasDelMes)
            return calendario.date(from: componentes)
        }

        guard let inicioEsteMes = inicioEnMes(de: fecha) else { return fecha }
        if fecha >= inicioEsteMes { return inicioEsteMes }
        guard let mesAnterior = calendario.date(byAdding: .month, value: -1, to: fecha),
              let inicioAnterior = inicioEnMes(de: mesAnterior)
        else { return inicioEsteMes }
        return inicioAnterior
    }

    // MARK: - Filtros y totales

    /// Movimientos del período financiero que contiene a `mes`.
    static func delMes(_ movimientos: [Movimiento], mes: Date = .now) -> [Movimiento] {
        let inicio = inicioPeriodo(conteniendo: mes)
        let fin = Calendar.current.date(byAdding: .month, value: 1, to: inicio) ?? inicio
        return movimientos.filter { $0.fecha >= inicio && $0.fecha < fin }
    }

    static func total(_ movimientos: [Movimiento], tipo: TipoMovimiento) -> Double {
        movimientos.filter { $0.tipo == tipo }.reduce(0) { $0 + $1.monto }
    }

    /// Ingresos - Gastos + Cashback.
    static func balance(_ movimientos: [Movimiento]) -> Double {
        movimientos.reduce(0) { $0 + $1.montoConSigno }
    }

    // MARK: - Porcentajes

    /// Fracción de los ingresos que se fue en gastos (0.76 → 76%).
    static func fraccionGastosSobreIngresos(_ movimientos: [Movimiento]) -> Double? {
        let ingresos = total(movimientos, tipo: .ingreso)
        guard ingresos > 0 else { return nil }
        return total(movimientos, tipo: .gasto) / ingresos
    }

    /// Fracción de los gastos recuperada como cashback.
    static func fraccionCashbackSobreGastos(_ movimientos: [Movimiento]) -> Double? {
        let gastos = total(movimientos, tipo: .gasto)
        guard gastos > 0 else { return nil }
        return total(movimientos, tipo: .cashback) / gastos
    }

    // MARK: - Promedios diarios

    /// Promedio diario de un total del período. Para el período en curso
    /// divide por los días transcurridos; para períodos cerrados, por su duración.
    static func promedioDiario(total: Double, mes: Date = .now) -> Double {
        let calendario = Calendar.current
        let inicio = inicioPeriodo(conteniendo: mes)
        let fin = calendario.date(byAdding: .month, value: 1, to: inicio) ?? inicio
        let dias: Int
        if (inicio..<fin).contains(.now) {
            dias = (calendario.dateComponents([.day], from: inicio, to: .now).day ?? 0) + 1
        } else {
            dias = calendario.dateComponents([.day], from: inicio, to: fin).day ?? 30
        }
        return dias > 0 ? total / Double(dias) : 0
    }

    // MARK: - Categorías

    /// Totales por categoría de un tipo, ordenados de mayor a menor.
    static func totalesPorCategoria(_ movimientos: [Movimiento], tipo: TipoMovimiento) -> [TotalCategoria] {
        let filtrados = movimientos.filter { $0.tipo == tipo }
        let agrupados = Dictionary(grouping: filtrados) { $0.categoriaRaw }
        return agrupados.compactMap { raw, items in
            guard let categoria = tipo.categoria(raw: raw) ?? CustomCategoryStore.categoria(raw: raw, tipo: tipo) else {
                return nil
            }
            return TotalCategoria(categoria: categoria, total: items.reduce(0) { $0 + $1.monto })
        }
        .sorted { $0.total > $1.total }
    }

    static func categoriaTop(_ movimientos: [Movimiento], tipo: TipoMovimiento) -> TotalCategoria? {
        totalesPorCategoria(movimientos, tipo: tipo).first
    }

    // MARK: - Variaciones y series

    /// Variación de un tipo respecto del mes anterior: (actual - anterior) / anterior.
    static func variacionMensual(_ movimientos: [Movimiento], tipo: TipoMovimiento, mes: Date = .now) -> Double? {
        let actual = total(delMes(movimientos, mes: mes), tipo: tipo)
        let anterior = total(delMes(movimientos, mes: mes.agregandoMeses(-1)), tipo: tipo)
        guard anterior > 0 else { return nil }
        return (actual - anterior) / anterior
    }

    /// Totales mensuales de los últimos `meses` meses, en orden cronológico.
    static func seriesMensuales(_ movimientos: [Movimiento], meses: Int = 6) -> [PuntoMensual] {
        (0..<meses).reversed().map { atras in
            let mes = Date.now.inicioDeMes.agregandoMeses(-atras)
            let movimientosDelMes = delMes(movimientos, mes: mes)
            return PuntoMensual(
                mes: mes,
                ingresos: total(movimientosDelMes, tipo: .ingreso),
                gastos: total(movimientosDelMes, tipo: .gasto),
                cashback: total(movimientosDelMes, tipo: .cashback)
            )
        }
    }

    // MARK: - Cuentas y tarjetas

    /// Saldo actual de una cuenta (no aplica a tarjetas de crédito).
    static func saldo(de cuenta: Cuenta) -> Double {
        cuenta.saldoInicial + (cuenta.movimientos ?? []).reduce(0) { $0 + $1.montoConSigno }
    }

    /// Total gastado con una cuenta durante el mes indicado.
    static func gastoDelMes(de cuenta: Cuenta, mes: Date = .now) -> Double {
        (cuenta.movimientos ?? [])
            .filter { $0.tipo == .gasto && $0.fecha.mismoMes(que: mes) }
            .reduce(0) { $0 + $1.monto }
    }

    /// Deuda actual de una tarjeta: compras del ciclo en curso más el saldo
    /// pendiente de las compras en cuotas (incluida la cuota del mes).
    static func consumoActual(de cuenta: Cuenta, al referencia: Date = .now) -> Double {
        guard cuenta.esTarjetaCredito else { return 0 }
        let inicioCiclo = cuenta.inicioCicloActual(desde: referencia)
        let gastos = (cuenta.movimientos ?? []).filter { $0.tipo == .gasto && $0.fecha <= referencia }

        return gastos.reduce(0) { acumulado, movimiento in
            if movimiento.esEnCuotas {
                let pendientesIncluyendoActual = movimiento.cuotas - movimiento.cuotaActual(al: referencia) + 1
                return acumulado + movimiento.montoCuota * Double(max(pendientesIncluyendoActual, 0))
            }
            if let inicioCiclo, movimiento.fecha >= inicioCiclo {
                return acumulado + movimiento.monto
            }
            return acumulado
        }
    }

    /// Crédito disponible de la tarjeta, si tiene límite configurado.
    static func disponible(de cuenta: Cuenta, al referencia: Date = .now) -> Double? {
        guard cuenta.esTarjetaCredito, cuenta.limite > 0 else { return nil }
        return max(cuenta.limite - consumoActual(de: cuenta, al: referencia), 0)
    }

    // MARK: - Presupuestos

    /// Total gastado en una categoría durante el mes indicado.
    static func gastado(en categoria: CategoriaGasto, movimientos: [Movimiento], mes: Date = .now) -> Double {
        delMes(movimientos, mes: mes)
            .filter { $0.tipo == .gasto && $0.categoriaRaw == categoria.rawValue }
            .reduce(0) { $0 + $1.monto }
    }

    // MARK: - Otros indicadores

    static func mayorGasto(_ movimientos: [Movimiento], mes: Date = .now) -> Movimiento? {
        delMes(movimientos, mes: mes)
            .filter { $0.tipo == .gasto }
            .max { $0.monto < $1.monto }
    }

    /// Índice de día de la semana (1 = domingo, como `Calendar.weekday`)
    /// en el que se concentra el mayor gasto histórico.
    static func diaSemanaConMasGasto(_ movimientos: [Movimiento]) -> Int? {
        let gastos = movimientos.filter { $0.tipo == .gasto }
        guard !gastos.isEmpty else { return nil }
        let porDia = Dictionary(grouping: gastos) {
            Calendar.current.component(.weekday, from: $0.fecha)
        }
        return porDia.max { a, b in
            a.value.reduce(0) { $0 + $1.monto } < b.value.reduce(0) { $0 + $1.monto }
        }?.key
    }
}
