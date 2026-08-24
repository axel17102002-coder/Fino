import SwiftUI

/// Fila de movimiento: ícono de categoría, nombre, detalle y monto coloreado.
struct TransactionRow: View {

    let movimiento: Movimiento
    /// En Movimientos la fecha está en el encabezado del día y repetirla
    /// en cada renglón solo hace ruido. En el detalle de una cuenta, donde
    /// la lista no está agrupada, sigue haciendo falta.
    var mostrarFecha: Bool = true
    /// Avisa cuándo pesa el gasto si no es en el mes de la compra.
    ///
    /// Con tarjeta, lo comprado después del cierre lo pagás en el resumen
    /// siguiente, así que la lista lo muestra bajo su fecha real pero los
    /// totales lo cuentan en otro mes. Sin este aviso parece un error.
    /// En el detalle de la tarjeta sobra: ahí ya está agrupado por
    /// resumen.
    var mostrarMesContable: Bool = false

    private var colorCategoria: Color {
        movimiento.categoria?.color ?? .gray
    }

    private var tieneTicket: Bool {
        movimiento.itemsTicket?.isEmpty == false
    }

    /// El mes en que pesa, cuando no es el de la compra.
    private var mesContable: String? {
        guard mostrarMesContable else { return nil }
        let contable = CalculosService.fechaContable(de: movimiento)
        let dePeriodo = CalculosService.inicioPeriodo(conteniendo: movimiento.fecha)
        let aPeriodo = CalculosService.inicioPeriodo(conteniendo: contable)
        guard dePeriodo != aPeriodo else { return nil }
        return contable.formatted(.dateTime.month(.wide))
    }

    private var subtitulo: String {
        var partes = [movimiento.nombreCategoria]
        if mostrarFecha { partes.append(movimiento.fecha.diaYMes) }
        if let cuenta = movimiento.cuenta { partes.append(cuenta.nombre) }
        return partes.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: movimiento.iconoCategoria)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(colorCategoria)
                .frame(width: 44, height: 44)
                .background(Circle().fill(colorCategoria.opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(movimiento.nombre)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    // Avisa que este gasto se cargó escaneando y que al
                    // tocarlo se abre el ticket en vez del formulario:
                    // sin la marca, el mismo toque hacía dos cosas
                    // distintas según un dato que no se veía.
                    if tieneTicket {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Tiene el detalle del ticket")
                    }
                }

                // Un solo Text y no varios en fila: con piezas sueltas,
                // cuando no entraban se partía la palabra ("Gro-" /
                // "ceries") y el punto separador quedaba descolocado.
                // Así se corta una vez sola, al final.
                Text(subtitulo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if movimiento.esEnCuotas {
                    Text("Cuota \(movimiento.cuotaActual())/\(movimiento.cuotas) · \(movimiento.montoCuota.enMoneda)/mes")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.rellenoTerciario))
                }

                if let mes = mesContable {
                    Text("Entra en \(mes)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.rellenoTerciario))
                }

                if movimiento.esCompartido {
                    Text("Compartido · Tu parte: \(movimiento.montoPropio.enMoneda)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.verdeIngreso)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.verdeIngreso.opacity(0.14)))
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(textoMonto)
                    .font(.callout.bold())
                    .monospacedDigit()
                    .foregroundStyle(movimiento.tipo.color)

                if let original = movimiento.montoOriginalFormateado {
                    Text(original)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var textoMonto: String {
        let signo = movimiento.tipo == .gasto ? "-" : "+"
        return "\(signo)\(movimiento.monto.enMoneda)"
    }
}
