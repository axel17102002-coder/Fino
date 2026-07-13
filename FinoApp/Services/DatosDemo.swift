import Foundation
import SwiftData

/// Datos de ejemplo para que la app se vea completa en el primer arranque.
/// Los totales del mes actual coinciden con los del diseño:
/// ingresos $2.500.000, gastos $1.900.000 y cashback $47.800.
enum DatosDemo {

    static func insertar(en contexto: ModelContext) {

        // MARK: Cuentas

        let galicia = Cuenta(
            nombre: "Galicia Visa",
            tipo: .tarjetaCredito,
            banco: "Banco Galicia",
            colorHex: "F97316",
            ultimosDigitos: "4321",
            limite: 2_000_000,
            diaCierre: 25,
            diaVencimiento: 7
        )
        let santander = Cuenta(
            nombre: "Santander Amex",
            tipo: .tarjetaCredito,
            banco: "Banco Santander",
            colorHex: "EC0000",
            ultimosDigitos: "8804",
            limite: 1_500_000,
            diaCierre: 20,
            diaVencimiento: 2
        )
        let efectivo = Cuenta(
            nombre: "Efectivo",
            tipo: .efectivo,
            colorHex: "22C55E",
            saldoInicial: 150_000
        )
        let mercadoPago = Cuenta(
            nombre: "Mercado Pago",
            tipo: .billeteraVirtual,
            colorHex: "00AEEF",
            saldoInicial: 85_000
        )
        let cuentaCorriente = Cuenta(
            nombre: "Cuenta Corriente",
            tipo: .cuentaBancaria,
            banco: "Banco Galicia",
            colorHex: "6366F1",
            saldoInicial: 900_000
        )
        let cuentas = [galicia, santander, efectivo, mercadoPago, cuentaCorriente]
        cuentas.forEach { contexto.insert($0) }

        // MARK: Movimientos del mes actual

        func fecha(dia: Int, mesesAtras: Int = 0) -> Date {
            Date.now.inicioDeMes.agregandoMeses(-mesesAtras).agregandoDias(dia - 1)
        }

        let ingresos: [(String, CategoriaIngreso, Double, Int, Cuenta)] = [
            ("Sueldo", .sueldo, 1_800_000, 1, cuentaCorriente),
            ("Alquiler depto Palermo", .alquiler, 450_000, 5, mercadoPago),
            ("Rendimientos inversiones", .inversiones, 250_000, 10, cuentaCorriente)
        ]
        for (nombre, categoria, monto, dia, cuenta) in ingresos {
            contexto.insert(Movimiento(
                tipo: .ingreso, nombre: nombre, categoriaRaw: categoria.rawValue,
                monto: monto, fecha: fecha(dia: dia), cuenta: cuenta
            ))
        }

        let gastos: [(String, CategoriaGasto, Double, Int, Cuenta)] = [
            ("Supermercado Coto", .supermercado, 420_000, 3, galicia),
            ("Salidas a comer", .comida, 180_000, 8, galicia),
            ("SUBE y nafta", .transporte, 95_000, 6, efectivo),
            ("Expensas", .hogar, 260_000, 5, cuentaCorriente),
            ("Netflix", .suscripciones, 12_000, 2, galicia),
            ("Spotify", .suscripciones, 8_000, 2, galicia),
            ("Apple One", .suscripciones, 17_000, 3, santander),
            ("iCloud", .suscripciones, 5_000, 3, santander),
            ("ChatGPT", .suscripciones, 40_000, 4, santander),
            ("Farmacia", .salud, 110_000, 12, galicia),
            ("Cine y salidas", .ocio, 140_000, 14, galicia),
            ("Ropa", .ropa, 150_000, 15, santander),
            ("Curso de inglés", .educacion, 120_000, 7, mercadoPago),
            ("Luz y gas", .servicios, 158_000, 9, cuentaCorriente),
            ("Veterinaria", .mascotas, 60_000, 16, efectivo),
            ("Regalo cumpleaños", .regalos, 75_000, 18, mercadoPago),
            ("Compras online", .comprasOnline, 50_000, 11, galicia)
        ]
        for (nombre, categoria, monto, dia, cuenta) in gastos {
            contexto.insert(Movimiento(
                tipo: .gasto, nombre: nombre, categoriaRaw: categoria.rawValue,
                monto: monto, fecha: fecha(dia: dia), cuenta: cuenta
            ))
        }

        // Compra en cuotas de hace dos meses, para ver el seguimiento de cuotas.
        contexto.insert(Movimiento(
            tipo: .gasto, nombre: "Notebook", categoriaRaw: CategoriaGasto.comprasOnline.rawValue,
            monto: 1_200_000, fecha: fecha(dia: 20, mesesAtras: 2),
            notas: "12 cuotas sin interés", cuotas: 12, cuenta: galicia
        ))

        let cashbacks: [(String, Double, Int, Cuenta)] = [
            ("Cashback supermercado", 12_500, 4, galicia),
            ("Cashback combustible", 9_800, 7, galicia),
            ("Cashback Mercado Pago", 15_500, 12, mercadoPago),
            ("Cashback restaurantes", 10_000, 15, santander)
        ]
        for (nombre, monto, dia, cuenta) in cashbacks {
            contexto.insert(Movimiento(
                tipo: .cashback, nombre: nombre, categoriaRaw: CategoriaCashback.cashback.rawValue,
                monto: monto, fecha: fecha(dia: dia), cuenta: cuenta
            ))
        }

        // MARK: Historial de meses anteriores (para los gráficos)

        let factores: [Double] = [0.92, 1.05, 0.88, 1.10, 0.95]
        for (indice, factor) in factores.enumerated() {
            let mesesAtras = indice + 1
            contexto.insert(Movimiento(
                tipo: .ingreso, nombre: "Sueldo", categoriaRaw: CategoriaIngreso.sueldo.rawValue,
                monto: 1_800_000, fecha: fecha(dia: 1, mesesAtras: mesesAtras), cuenta: cuentaCorriente
            ))
            contexto.insert(Movimiento(
                tipo: .ingreso, nombre: "Alquiler depto Palermo", categoriaRaw: CategoriaIngreso.alquiler.rawValue,
                monto: 450_000, fecha: fecha(dia: 5, mesesAtras: mesesAtras), cuenta: mercadoPago
            ))

            let gastosMes: [(String, CategoriaGasto, Double, Int, Cuenta)] = [
                ("Supermercado", .supermercado, 400_000 * factor, 4, galicia),
                ("Comida", .comida, 170_000 * factor, 9, galicia),
                ("Servicios", .servicios, 150_000 * factor, 10, cuentaCorriente),
                ("Ocio", .ocio, 120_000 * factor, 15, santander),
                ("Transporte", .transporte, 90_000 * factor, 7, efectivo),
                ("Expensas", .hogar, 260_000, 5, cuentaCorriente)
            ]
            for (nombre, categoria, monto, dia, cuenta) in gastosMes {
                contexto.insert(Movimiento(
                    tipo: .gasto, nombre: nombre, categoriaRaw: categoria.rawValue,
                    monto: monto.rounded(), fecha: fecha(dia: dia, mesesAtras: mesesAtras), cuenta: cuenta
                ))
            }

            contexto.insert(Movimiento(
                tipo: .cashback, nombre: "Cashback del mes", categoriaRaw: CategoriaCashback.cashback.rawValue,
                monto: (40_000 * factor).rounded(), fecha: fecha(dia: 12, mesesAtras: mesesAtras), cuenta: galicia
            ))
        }

        // MARK: Presupuestos

        let presupuestos: [(CategoriaGasto, Double)] = [
            (.comida, 250_000),
            (.supermercado, 450_000),
            (.ocio, 150_000),
            (.suscripciones, 90_000),
            (.transporte, 120_000)
        ]
        for (categoria, monto) in presupuestos {
            contexto.insert(Presupuesto(categoria: categoria, montoMensual: monto))
        }

        // MARK: Objetivos de ahorro

        contexto.insert(ObjetivoAhorro(
            nombre: "Vacaciones", icono: "beach.umbrella.fill",
            colorHex: "0EA5E9", meta: 3_000_000, ahorrado: 1_450_000
        ))
        contexto.insert(ObjetivoAhorro(
            nombre: "iPhone nuevo", icono: "iphone",
            colorHex: "8B5CF6", meta: 1_200, ahorrado: 350, moneda: .usd
        ))

        try? contexto.save()
    }
}
