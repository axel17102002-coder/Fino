import SwiftUI

/// Próximos cierres y vencimientos de las tarjetas de crédito, con el
/// consumo actual de cada una. Solo aparece si alguna tarjeta tiene
/// configurado el día de cierre o de vencimiento.
struct VencimientosCard: View {

    let tarjetas: [Cuenta]

    private struct Item: Identifiable {
        let id: UUID
        let nombre: String
        let icono: String
        let color: Color
        let detalle: String
        let proximoEvento: Date
        let diasRestantes: Int
        let esVencimiento: Bool
        let consumo: Double
    }

    private var items: [Item] {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: .now)

        return tarjetas.compactMap { tarjeta -> Item? in
            let cierre = tarjeta.diaCierre > 0
                ? CalculosService.proximaFecha(dia: tarjeta.diaCierre) : nil
            let vencimiento = tarjeta.diaVencimiento > 0
                ? CalculosService.proximaFecha(dia: tarjeta.diaVencimiento) : nil
            guard cierre != nil || vencimiento != nil else { return nil }

            var partes: [String] = []
            if let cierre {
                partes.append(String(localized: "Cierra el \(cierre.formatted(.dateTime.day().month(.abbreviated)))"))
            }
            if let vencimiento {
                partes.append(String(localized: "Vence el \(vencimiento.formatted(.dateTime.day().month(.abbreviated)))"))
            }

            let candidatos = [cierre, vencimiento].compactMap { $0 }
            guard let proximo = candidatos.min() else { return nil }
            let dias = calendario.dateComponents([.day], from: hoy, to: proximo).day ?? 0

            return Item(
                id: tarjeta.id,
                nombre: tarjeta.nombre,
                icono: tarjeta.icono,
                color: Color(hex: tarjeta.colorHex),
                detalle: partes.joined(separator: " · "),
                proximoEvento: proximo,
                diasRestantes: dias,
                esVencimiento: proximo == vencimiento,
                consumo: CalculosService.consumoActual(de: tarjeta)
            )
        }
        .sorted { $0.proximoEvento < $1.proximoEvento }
    }

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: 12) {
                ForEach(items) { item in
                    fila(item)
                }
            }
            .estiloTarjeta(padding: 16)
        }
    }

    private func fila(_ item: Item) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icono)
                .font(.subheadline)
                .foregroundStyle(item.color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(item.color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.nombre)
                    .font(.subheadline.weight(.semibold))
                Text(item.detalle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.consumo.enMonedaCompacta)
                    .font(.callout.bold())
                    .monospacedDigit()
                chip(dias: item.diasRestantes, esVencimiento: item.esVencimiento)
            }
        }
    }

    private func chip(dias: Int, esVencimiento: Bool) -> some View {
        let texto: String = switch dias {
        case 0: String(localized: "Hoy")
        case 1: String(localized: "Mañana")
        default: String(localized: "En \(dias) días")
        }
        let color: Color = dias <= 3 ? .red : (dias <= 7 ? .orange : .secondary)

        return Text(texto)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}
