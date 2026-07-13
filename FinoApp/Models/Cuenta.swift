import Foundation
import SwiftData
import SwiftUI

@Model
final class Cuenta {
    @Attribute(.unique) var id: UUID
    var nombre: String
    var tipoRaw: String
    var banco: String
    var icono: String
    var colorHex: String
    /// Últimos 4 dígitos de la tarjeta (solo tarjetas de crédito).
    var ultimosDigitos: String
    /// Límite de compra de la tarjeta. `0` significa sin límite configurado.
    var limite: Double
    /// Día del mes en que cierra el resumen (solo tarjetas de crédito).
    var diaCierre: Int
    /// Día del mes en que vence el resumen (solo tarjetas de crédito).
    var diaVencimiento: Int
    /// Saldo con el que arranca la cuenta al crearla (no aplica a tarjetas).
    var saldoInicial: Double
    /// Posición elegida por el usuario al reordenar las listas.
    var orden: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Movimiento.cuenta)
    var movimientos: [Movimiento]?

    init(
        nombre: String,
        tipo: TipoCuenta,
        banco: String = "",
        icono: String? = nil,
        colorHex: String = "6366F1",
        ultimosDigitos: String = "",
        limite: Double = 0,
        diaCierre: Int = 0,
        diaVencimiento: Int = 0,
        saldoInicial: Double = 0
    ) {
        self.id = UUID()
        self.nombre = nombre
        self.tipoRaw = tipo.rawValue
        self.banco = banco
        self.icono = icono ?? tipo.icono
        self.colorHex = colorHex
        self.ultimosDigitos = ultimosDigitos
        self.limite = limite
        self.diaCierre = diaCierre
        self.diaVencimiento = diaVencimiento
        self.saldoInicial = saldoInicial
    }

    // MARK: - Derivados

    var tipo: TipoCuenta {
        get { TipoCuenta(rawValue: tipoRaw) ?? .efectivo }
        set { tipoRaw = newValue.rawValue }
    }

    var esTarjetaCredito: Bool { tipo == .tarjetaCredito }

    var color: Color { Color(hex: colorHex) }

    var movimientosOrdenados: [Movimiento] {
        (movimientos ?? []).sorted { $0.fecha > $1.fecha }
    }

    // MARK: - Ciclo de la tarjeta

    /// Próxima fecha de cierre del resumen a partir de la fecha dada.
    func proximoCierre(desde referencia: Date = .now) -> Date? {
        guard esTarjetaCredito else { return nil }
        return Self.proximaFecha(dia: diaCierre, desde: referencia)
    }

    /// Próxima fecha de vencimiento del resumen a partir de la fecha dada.
    func proximoVencimiento(desde referencia: Date = .now) -> Date? {
        guard esTarjetaCredito else { return nil }
        return Self.proximaFecha(dia: diaVencimiento, desde: referencia)
    }

    /// Próxima ocurrencia de un día del mes (1 al 31). Si el mes no llega a
    /// ese día (ej: 31 en febrero), se usa el último día del mes.
    private static func proximaFecha(dia: Int, desde referencia: Date) -> Date? {
        guard (1...31).contains(dia) else { return nil }
        let calendario = Calendar.current
        for offsetMes in 0...2 {
            guard let mes = calendario.date(byAdding: .month, value: offsetMes, to: referencia),
                  let diasDelMes = calendario.range(of: .day, in: .month, for: mes)?.count
            else { continue }
            var componentes = calendario.dateComponents([.year, .month], from: mes)
            componentes.day = min(dia, diasDelMes)
            if let fecha = calendario.date(from: componentes), fecha > referencia {
                return fecha
            }
        }
        return nil
    }

    /// Inicio del ciclo de facturación actual (el día siguiente al último cierre).
    func inicioCicloActual(desde referencia: Date = .now) -> Date? {
        guard let cierre = proximoCierre(desde: referencia) else { return nil }
        return Calendar.current.date(byAdding: .month, value: -1, to: cierre)
    }
}
