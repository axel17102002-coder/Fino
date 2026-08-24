import SwiftUI

/// Los últimos movimientos, para chequear de un vistazo qué se cargó sin
/// sacar el teléfono. Es solo lectura: editar y borrar siguen en el iPhone.
struct UltimosWatchView: View {

    @Environment(ConexionWatch.self) private var conexion

    private var datos: SnapshotWatch { conexion.datos }

    var body: some View {
        Group {
            if !conexion.hayDatos {
                ScrollView { SinDatosWatch().padding(.top, 20) }
            } else if datos.ultimos.isEmpty {
                ScrollView {
                    Text("Todavía no hay movimientos")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                }
            } else {
                List {
                    ForEach(datos.ultimos) { movimiento in
                        renglon(movimiento)
                    }
                    if conexion.pendientes > 0 {
                        pendientes
                    }
                }
            }
        }
        .navigationTitle("Últimos")
    }

    private func renglon(_ movimiento: SnapshotWatch.MovimientoResumido) -> some View {
        HStack(spacing: 8) {
            Image(systemName: movimiento.icono)
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color(hex: movimiento.colorHex)))

            VStack(alignment: .leading, spacing: 0) {
                Text(movimiento.nombre)
                    .font(.caption2)
                    .lineLimit(1)
                Text(movimiento.fecha.cortaParaWatch)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 2)

            Text(monto(movimiento))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(movimiento.esGasto ? .primary : Color.green)
        }
        .padding(.vertical, 2)
    }

    private func monto(_ movimiento: SnapshotWatch.MovimientoResumido) -> String {
        let formateado = datos.formatearCorto(movimiento.monto)
        return movimiento.esGasto ? formateado : "+\(formateado)"
    }

    /// Gastos cargados acá que el iPhone todavía no acusó recibo.
    private var pendientes: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 9))
            Text("\(conexion.pendientes) sin sincronizar")
                .font(.system(size: 10))
        }
        .foregroundStyle(.secondary)
    }
}
