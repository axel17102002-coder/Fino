import Charts
import SwiftUI

/// Pantalla principal: la dona de gastos del mes, la misma idea que el
/// Dashboard del iPhone pero sin tarjetas, sin cuentas y sin carrusel.
struct ResumenWatchView: View {

    @Environment(ConexionWatch.self) private var conexion

    /// Categoría resaltada. En el reloj no se toca la dona (los dedos no
    /// entran): se elige tocando el renglón de abajo.
    @State private var seleccion: String?

    private var datos: SnapshotWatch { conexion.datos }

    private var porcionSeleccionada: SnapshotWatch.PorcionCategoria? {
        guard let seleccion else { return nil }
        return datos.porCategoria.first { $0.raw == seleccion }
    }

    var body: some View {
        ScrollView {
            if conexion.hayDatos {
                VStack(spacing: 10) {
                    encabezado
                    if datos.porCategoria.isEmpty {
                        sinGastos
                    } else {
                        dona
                        categorias
                    }
                }
            } else {
                SinDatosWatch()
                    .padding(.top, 20)
            }
        }
        .navigationTitle("Fino")
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        VStack(spacing: 2) {
            Text(datos.mes)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(datos.formatear(datos.balance))
                .font(.title3.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(datos.balance < 0 ? .red : Color.crema)
            Text("Balance del mes")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Dona

    private var dona: some View {
        Chart(datos.porCategoria) { porcion in
            SectorMark(
                angle: .value("Monto", porcion.monto),
                innerRadius: .ratio(0.66),
                outerRadius: seleccion == porcion.raw ? .ratio(1.0) : .ratio(0.88),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(Color(hex: porcion.colorHex).gradient)
            .opacity(seleccion == nil || seleccion == porcion.raw ? 1 : 0.28)
        }
        .chartLegend(.hidden)
        .frame(height: 116)
        .overlay { centro }
        .animation(.snappy(duration: 0.3), value: seleccion)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gastos del mes por categoría")
        .accessibilityValue(
            datos.porCategoria
                .map { "\($0.nombre): \(datos.formatear($0.monto))" }
                .joined(separator: ", ")
        )
    }

    private var centro: some View {
        VStack(spacing: 1) {
            Text(porcionSeleccionada?.nombre ?? String(localized: "Gastos"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(datos.formatearCorto(porcionSeleccionada?.monto ?? datos.gastos))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .foregroundStyle(
                    porcionSeleccionada.map { Color(hex: $0.colorHex) } ?? .primary
                )
        }
        .padding(.horizontal, 26)
    }

    // MARK: - Renglones de categoría

    private var categorias: some View {
        VStack(spacing: 4) {
            ForEach(datos.porCategoria.prefix(6)) { porcion in
                Button {
                    seleccion = seleccion == porcion.raw ? nil : porcion.raw
                } label: {
                    renglon(porcion)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func renglon(_ porcion: SnapshotWatch.PorcionCategoria) -> some View {
        HStack(spacing: 7) {
            Image(systemName: porcion.icono)
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color(hex: porcion.colorHex)))

            VStack(alignment: .leading, spacing: 0) {
                Text(porcion.nombre)
                    .font(.caption2)
                    .lineLimit(1)
                Text(porcentaje(porcion.monto))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 2)

            Text(datos.formatearCorto(porcion.monto))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(.white.opacity(seleccion == porcion.raw ? 0.2 : 0.08))
        )
    }

    private func porcentaje(_ monto: Double) -> String {
        String(format: "%.0f%%", datos.fraccion(monto) * 100)
    }

    // MARK: - Mes sin gastos

    private var sinGastos: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.pie")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Todavía no cargaste gastos este mes")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }
}
