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
    /// Suma de los balances mensuales desde el primer movimiento registrado
    /// hasta el fin de este mes: cuánto se llevás ahorrado (o de rojo) en total.
    let acumulado: Double

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

    /// Próxima ocurrencia de un día del mes (hoy cuenta). Si el mes no
    /// llega a ese día (31 en febrero), usa el último día del mes.
    static func proximaFecha(dia: Int, desde referencia: Date = .now) -> Date? {
        guard (1...31).contains(dia) else { return nil }
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: referencia)

        func fecha(enMesDe base: Date) -> Date? {
            var componentes = calendario.dateComponents([.year, .month], from: base)
            guard let mes = calendario.date(from: componentes),
                  let diasDelMes = calendario.range(of: .day, in: .month, for: mes)?.count
            else { return nil }
            componentes.day = min(dia, diasDelMes)
            return calendario.date(from: componentes)
        }

        if let esteMes = fecha(enMesDe: hoy), esteMes >= hoy {
            return esteMes
        }
        guard let mesQueViene = calendario.date(byAdding: .month, value: 1, to: hoy) else {
            return nil
        }
        return fecha(enMesDe: mesQueViene)
    }

    // MARK: - Filtros y totales

    /// Movimientos que aportan al período financiero que contiene a `mes`,
    /// con lo que aporta cada uno.
    ///
    /// Una compra financiada **no** cae entera en el mes que la hiciste:
    /// aporta una cuota por mes mientras dure el plan. Antes se contaba
    /// el total en el mes de la compra, así que 120.000 en 12 cuotas
    /// inflaban ese mes y dejaban los once siguientes en blanco aunque
    /// siguieras pagando 10.000 todos los meses.
    static func delMes(_ movimientos: [Movimiento], mes: Date = .now) -> [AporteMensual] {
        let inicio = inicioPeriodo(conteniendo: mes)
        return movimientos.compactMap { movimiento in
            let monto = aporte(de: movimiento, alPeriodoQueEmpieza: inicio)
            return monto > 0 ? AporteMensual(movimiento: movimiento, monto: monto) : nil
        }
    }

    /// La fecha con la que un gasto entra en los totales.
    ///
    /// Con tarjeta de crédito no es la de la compra: lo que comprás
    /// después del cierre no lo pagás en ese resumen sino en el
    /// siguiente. Una compra del 28 con cierre el 25 pesa en el mes que
    /// viene, aunque la hayas hecho este.
    ///
    /// Se toma el primer cierre igual o posterior a la compra, así que
    /// comprar **el día** del cierre entra en ese resumen y no en el otro.
    /// Sin día de cierre configurado —o sin tarjeta— vale la fecha real.
    static func fechaContable(de movimiento: Movimiento) -> Date {
        guard let cuenta = movimiento.cuenta,
              cuenta.esTarjetaCredito,
              cuenta.diaCierre > 0,
              let cierre = proximaFecha(dia: cuenta.diaCierre, desde: movimiento.fecha)
        else { return movimiento.fecha }
        return cierre
    }

    /// Lo que un movimiento aporta al período que arranca en `inicio`.
    ///
    /// Pago único: el monto entero, si su fecha contable cae dentro del
    /// período. Financiado: la cuota, mientras el período esté dentro del
    /// plan, contando desde el resumen en el que entró la compra. Las
    /// cuotas se cuentan por períodos —no por días— para que respeten el
    /// "el mes empieza el 5" de Configuración.
    static func aporte(de movimiento: Movimiento, alPeriodoQueEmpieza inicio: Date) -> Double {
        let fecha = fechaContable(de: movimiento)

        guard movimiento.esEnCuotas else {
            let fin = Calendar.current.date(byAdding: .month, value: 1, to: inicio) ?? inicio
            return (fecha >= inicio && fecha < fin) ? movimiento.montoPropio : 0
        }

        let inicioDeLaCompra = inicioPeriodo(conteniendo: fecha)
        let meses = Calendar.current.dateComponents(
            [.month], from: inicioDeLaCompra, to: inicio
        ).month ?? 0
        let cuota = meses + 1
        guard cuota >= 1, cuota <= movimiento.cuotas else { return 0 }
        return movimiento.montoPropio / Double(movimiento.cuotas)
    }

    /// Total de un tipo contando solo el consumo propio: los gastos
    /// compartidos aportan tu parte y las devoluciones de deudas no
    /// cuentan como ingreso.
    static func total(_ movimientos: [Movimiento], tipo: TipoMovimiento) -> Double {
        movimientos.filter { $0.tipo == tipo }.reduce(0) { $0 + $1.montoPropio }
    }

    static func total(_ aportes: [AporteMensual], tipo: TipoMovimiento) -> Double {
        aportes.filter { $0.tipo == tipo }.reduce(0) { $0 + $1.monto }
    }

    /// Ingresos - Gastos + Cashback (consumo propio).
    static func balance(_ movimientos: [Movimiento]) -> Double {
        movimientos.reduce(0) { $0 + $1.montoPropioConSigno }
    }

    static func balance(_ aportes: [AporteMensual]) -> Double {
        aportes.reduce(0) { $0 + $1.conSigno }
    }

    // MARK: - Porcentajes

    /// Fracción de los ingresos que se fue en gastos (0.76 → 76%).
    static func fraccionGastosSobreIngresos(_ aportes: [AporteMensual]) -> Double? {
        let ingresos = total(aportes, tipo: .ingreso)
        guard ingresos > 0 else { return nil }
        return total(aportes, tipo: .gasto) / ingresos
    }

    /// Fracción de los gastos recuperada como cashback.
    static func fraccionCashbackSobreGastos(_ aportes: [AporteMensual]) -> Double? {
        let gastos = total(aportes, tipo: .gasto)
        guard gastos > 0 else { return nil }
        return total(aportes, tipo: .cashback) / gastos
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
    static func totalesPorCategoria(_ aportes: [AporteMensual], tipo: TipoMovimiento) -> [TotalCategoria] {
        let filtrados = aportes.filter { $0.tipo == tipo }
        let agrupados = Dictionary(grouping: filtrados) { $0.categoriaRaw }
        return agrupados.compactMap { raw, items in
            guard let categoria = tipo.categoria(raw: raw) ?? CustomCategoryStore.categoria(raw: raw, tipo: tipo) else {
                return nil
            }
            return TotalCategoria(categoria: categoria, total: items.reduce(0) { $0 + $1.monto })
        }
        .sorted { $0.total > $1.total }
    }

    static func categoriaTop(_ aportes: [AporteMensual], tipo: TipoMovimiento) -> TotalCategoria? {
        totalesPorCategoria(aportes, tipo: tipo).first
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
    /// El acumulado arranca del balance de todo lo anterior a la ventana
    /// visible, no de cero, para que refleje el ahorro real desde el
    /// primer movimiento aunque el gráfico solo muestre los últimos meses.
    static func seriesMensuales(_ movimientos: [Movimiento], meses: Int = 6) -> [PuntoMensual] {
        let inicioVentana = Date.now.inicioDeMes.agregandoMeses(-(meses - 1))
        var acumulado = balance(movimientos.filter { $0.fecha < inicioVentana })

        return (0..<meses).reversed().map { atras in
            let mes = Date.now.inicioDeMes.agregandoMeses(-atras)
            let movimientosDelMes = delMes(movimientos, mes: mes)
            acumulado += balance(movimientosDelMes)
            return PuntoMensual(
                mes: mes,
                ingresos: total(movimientosDelMes, tipo: .ingreso),
                gastos: total(movimientosDelMes, tipo: .gasto),
                cashback: total(movimientosDelMes, tipo: .cashback),
                acumulado: acumulado
            )
        }
    }

    // MARK: - Cuentas y tarjetas

    /// Saldo actual de una cuenta (no aplica a tarjetas de crédito).
    static func saldo(de cuenta: Cuenta) -> Double {
        cuenta.saldoInicial + (cuenta.movimientos ?? []).reduce(0) { $0 + $1.montoConSigno }
    }

    /// Total gastado con una cuenta durante el mes indicado.
    /// Pasa por `delMes`, así que cuenta lo mismo que el resto de la app:
    /// la cuota que toca este mes y no el total de la compra, tu parte de
    /// lo compartido, y el resumen al que entró según el cierre.
    static func gastoDelMes(de cuenta: Cuenta, mes: Date = .now) -> Double {
        total(delMes(cuenta.movimientos ?? [], mes: mes), tipo: .gasto)
    }

    /// Lo que va del resumen en curso: las compras de este ciclo más la
    /// cuota que le toca a lo financiado.
    ///
    /// Una sola cuota, no el saldo pendiente entero. Antes sumaba las
    /// doce cuotas de una compra en el mismo momento de hacerla, así que
    /// la tarjeta mostraba 120.000 el día que gastaste 120.000 en doce
    /// veces, cuando en ese resumen te van a cobrar 10.000. Para ver la
    /// deuda total está `saldoPendiente` del movimiento.
    static func consumoActual(de cuenta: Cuenta, al referencia: Date = .now) -> Double {
        guard cuenta.esTarjetaCredito else { return 0 }
        let inicioCiclo = cuenta.inicioCicloActual(desde: referencia)
        let gastos = (cuenta.movimientos ?? []).filter { $0.tipo == .gasto && $0.fecha <= referencia }

        return gastos.reduce(0) { acumulado, movimiento in
            if movimiento.esEnCuotas {
                // Sin recortar: `cuotaActual` acota a 1...cuotas y con eso
                // un plan terminado seguía sumando su última cuota para
                // siempre.
                let cuota = movimiento.numeroDeCuota(al: referencia)
                return cuota >= 1 && cuota <= movimiento.cuotas
                    ? acumulado + movimiento.montoCuota
                    : acumulado
            }
            if let inicioCiclo, movimiento.fecha >= inicioCiclo {
                return acumulado + movimiento.monto
            }
            return acumulado
        }
    }

    /// Importe del resumen que ya cerró: las compras del ciclo anterior
    /// más la cuota que le toca a las compras financiadas.
    static func resumenCerrado(de cuenta: Cuenta, al referencia: Date = .now) -> Double {
        guard cuenta.esTarjetaCredito,
              let inicio = cuenta.inicioResumenCerrado(desde: referencia),
              let cierre = cuenta.inicioCicloActual(desde: referencia)
        else { return 0 }

        return (cuenta.movimientos ?? [])
            .filter { $0.tipo == .gasto }
            .reduce(0) { acumulado, movimiento in
                if movimiento.esEnCuotas {
                    // Una cuota por resumen, mientras el plan siga vivo.
                    let cuota = movimiento.numeroDeCuota(al: cierre)
                    return cuota >= 1 && cuota <= movimiento.cuotas
                        ? acumulado + movimiento.montoCuota
                        : acumulado
                }
                return movimiento.fecha >= inicio && movimiento.fecha < cierre
                    ? acumulado + movimiento.monto
                    : acumulado
            }
    }

    /// Hay un resumen cerrado con saldo y todavía sin pagar.
    ///
    /// Pide que el importe sea mayor a cero además de que esté sin
    /// marcar: una tarjeta recién creada, o una que no se usó en todo el
    /// ciclo, no tiene nada que pagar y mostrarle "A pagar $ 0" no tenía
    /// sentido.
    static func hayResumenAPagar(de cuenta: Cuenta, al referencia: Date = .now) -> Bool {
        cuenta.tieneResumenSinPagar(al: referencia)
            && resumenCerrado(de: cuenta, al: referencia) > 0
    }

    /// Lo que hay que mostrar en la tarjeta: mientras el resumen cerrado
    /// esté sin pagar, ese importe —que es la plata que hay que poner— y
    /// una vez pagado, el consumo del ciclo que está corriendo.
    ///
    /// Antes se mostraba siempre el ciclo en curso, así que al pasar el
    /// cierre la tarjeta se ponía en cero justo el día en que más
    /// importaba saber cuánto se debía.
    static func importeAMostrar(de cuenta: Cuenta, al referencia: Date = .now) -> Double {
        hayResumenAPagar(de: cuenta, al: referencia)
            ? resumenCerrado(de: cuenta, al: referencia)
            : consumoActual(de: cuenta, al: referencia)
    }

    /// Crédito disponible de la tarjeta, si tiene límite configurado.
    static func disponible(de cuenta: Cuenta, al referencia: Date = .now) -> Double? {
        guard cuenta.esTarjetaCredito, cuenta.limite > 0 else { return nil }
        return max(cuenta.limite - consumoActual(de: cuenta, al: referencia), 0)
    }

    // MARK: - Presupuestos

    /// Total gastado en una categoría durante el mes indicado (tu parte).
    static func gastado(en categoria: CategoriaGasto, movimientos: [Movimiento], mes: Date = .now) -> Double {
        delMes(movimientos, mes: mes)
            .filter { $0.tipo == .gasto && $0.categoriaRaw == categoria.rawValue }
            .reduce(0) { $0 + $1.monto }
    }

    // MARK: - Otros indicadores

    /// El gasto más grande del mes. Con una compra en cuotas compara la
    /// cuota, no el total: lo que pesó este mes.
    static func mayorGasto(_ movimientos: [Movimiento], mes: Date = .now) -> Movimiento? {
        delMes(movimientos, mes: mes)
            .filter { $0.tipo == .gasto }
            .max { $0.monto < $1.monto }?
            .movimiento
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
            a.value.reduce(0) { $0 + $1.montoPropio } < b.value.reduce(0) { $0 + $1.montoPropio }
        }?.key
    }
}
