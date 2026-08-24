import SwiftUI
import UIKit

/// Muestra un gasto escaneado con la forma del ticket de papel: los
/// productos con su precio, el descuento y el total abajo.
///
/// Es lo primero que aparece al tocar un movimiento que tenga detalle;
/// el formulario de edición queda a un botón de distancia. Un gasto sin
/// detalle abre el formulario directo, como siempre.
struct TicketSheet: View {

    let movimiento: Movimiento

    @Environment(\.dismiss) private var cerrar
    @State private var editando = false

    private var items: [ItemTicket] { movimiento.itemsTicket ?? [] }
    private var productos: [ItemTicket] { items.filter { $0.monto > 0 } }
    private var descuentos: [ItemTicket] { items.filter { $0.monto < 0 } }

    var body: some View {
        NavigationStack {
            ScrollView {
                papel
                    .padding(.horizontal, 22)
                    .padding(.vertical, 28)
            }
            .background(Color.fondoPantalla.ignoresSafeArea())
            .navigationTitle("Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Editar") { editando = true }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $editando) {
                AddTransactionSheet(movimiento: movimiento)
            }
        }
    }

    private var papel: some View {
        VStack(spacing: 16) {
            encabezado
            separador
            renglones
            separador
            totales
            pie
        }
        .font(.system(.footnote, design: .monospaced))
        .foregroundStyle(Color.tintaTicket)
        // El relleno de arriba y abajo deja lugar a los dientes del papel.
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background {
            PapelDeTicket()
                .fill(Color.papelTicket)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
    }

    private var encabezado: some View {
        VStack(spacing: 6) {
            Text(movimiento.nombre.uppercased())
                .font(.system(.headline, design: .monospaced).weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(movimiento.fecha.formatted(date: .long, time: .omitted))
                .font(.system(.caption, design: .monospaced))
                .opacity(0.7)

            if let cuenta = movimiento.cuenta {
                Text(cuenta.nombre)
                    .font(.system(.caption, design: .monospaced))
                    .opacity(0.7)
            }
        }
    }

    private var renglones: some View {
        VStack(spacing: 10) {
            ForEach(Array(productos.enumerated()), id: \.offset) { _, item in
                renglon(item.nombre, monto: item.monto)
            }
            ForEach(Array(descuentos.enumerated()), id: \.offset) { _, item in
                renglon(item.nombre, monto: item.monto)
                    .opacity(0.75)
            }
        }
    }

    private func renglon(_ nombre: String, monto: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(nombre)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Text(monto.enMoneda)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var totales: some View {
        VStack(spacing: 8) {
            if !descuentos.isEmpty {
                renglon(String(localized: "Sin descuentos"), monto: productos.total)
                    .opacity(0.7)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("TOTAL")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                Spacer(minLength: 8)
                Text(movimiento.monto.enMoneda)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private var pie: some View {
        VStack(spacing: 10) {
            Text(resumen)
                .font(.system(.caption2, design: .monospaced))
                .opacity(0.65)
                .multilineTextAlignment(.center)

            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 62)
                .opacity(0.5)
        }
        .padding(.top, 4)
    }

    private var resumen: String {
        let cantidad = productos.count
        let categoria = movimiento.nombreCategoria
        return cantidad == 1
            ? String(localized: "1 producto · \(categoria)")
            : String(localized: "\(cantidad) productos · \(categoria)")
    }

    private var separador: some View {
        // Línea de guiones, como la que imprime la caja.
        Rectangle()
            .fill(Color.tintaTicket.opacity(0.35))
            .frame(height: 1)
            .mask {
                HStack(spacing: 4) {
                    ForEach(0..<40, id: \.self) { _ in
                        Rectangle().frame(width: 5)
                    }
                }
            }
    }
}

/// Silueta del papel: rectángulo con los bordes de arriba y de abajo
/// dentados, como cuando se corta el ticket de la impresora.
private struct PapelDeTicket: Shape {

    var anchoDiente: CGFloat = 16
    var altoDiente: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var camino = Path()
        let dientes = max(2, Int((rect.width / anchoDiente).rounded()))
        let paso = rect.width / CGFloat(dientes)

        camino.move(to: CGPoint(x: rect.minX, y: rect.minY + altoDiente))
        for diente in 0..<dientes {
            let inicio = rect.minX + paso * CGFloat(diente)
            camino.addLine(to: CGPoint(x: inicio + paso / 2, y: rect.minY))
            camino.addLine(to: CGPoint(x: inicio + paso, y: rect.minY + altoDiente))
        }

        camino.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - altoDiente))
        for diente in 0..<dientes {
            let inicio = rect.maxX - paso * CGFloat(diente)
            camino.addLine(to: CGPoint(x: inicio - paso / 2, y: rect.maxY))
            camino.addLine(to: CGPoint(x: inicio - paso, y: rect.maxY - altoDiente))
        }

        camino.closeSubpath()
        return camino
    }
}

extension Color {

    /// Papel del ticket: crema en claro, y en oscuro un marrón apagado
    /// para que la hoja no encandile en una pantalla negra.
    static var papelTicket: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x2B / 255, green: 0x26 / 255, blue: 0x20 / 255, alpha: 1)
                : UIColor(red: 0xFF / 255, green: 0xE7 / 255, blue: 0xC2 / 255, alpha: 1)
        })
    }

    /// Tinta de la impresora, siempre contra el papel.
    static var tintaTicket: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0xED / 255, green: 0xE3 / 255, blue: 0xD2 / 255, alpha: 1)
                : UIColor(red: 0x3A / 255, green: 0x32 / 255, blue: 0x26 / 255, alpha: 1)
        })
    }
}
