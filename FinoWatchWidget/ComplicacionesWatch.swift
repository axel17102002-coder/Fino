import SwiftUI
import WidgetKit

// MARK: - Datos

/// Lee el snapshot que la app del reloj dejó en el App Group.
///
/// La complicación no habla con el iPhone: se limita a mostrar lo último
/// que la app guardó. Cuando llega un snapshot nuevo, `ConexionWatch`
/// llama a `WidgetCenter.reloadAllTimelines()` y esto se vuelve a leer.
enum DatosComplicacion {

    static func snapshot() -> SnapshotWatch? {
        guard let defaults = UserDefaults(suiteName: PayloadWatch.grupo),
              let data = defaults.data(forKey: PayloadWatch.claveSnapshotGuardado) else {
            return nil
        }
        return try? JSONDecoder().decode(SnapshotWatch.self, from: data)
    }

    /// Lo que se dibuja en la galería de complicaciones, donde todavía no
    /// hay datos reales del usuario.
    static var ejemplo: SnapshotWatch {
        var muestra = SnapshotWatch.vacio
        muestra.mes = "Agosto 2026"
        muestra.gastos = 1_900_000
        muestra.ingresos = 2_500_000
        muestra.balance = 647_800
        return muestra
    }
}

struct EntradaComplicacion: TimelineEntry {
    let date: Date
    let snapshot: SnapshotWatch?
}

struct ProveedorComplicacion: TimelineProvider {

    func placeholder(in context: Context) -> EntradaComplicacion {
        EntradaComplicacion(date: .now, snapshot: DatosComplicacion.ejemplo)
    }

    func getSnapshot(in context: Context, completion: @escaping (EntradaComplicacion) -> Void) {
        let datos = context.isPreview
            ? DatosComplicacion.ejemplo
            : (DatosComplicacion.snapshot() ?? DatosComplicacion.ejemplo)
        completion(EntradaComplicacion(date: .now, snapshot: datos))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntradaComplicacion>) -> Void) {
        let entrada = EntradaComplicacion(date: .now, snapshot: DatosComplicacion.snapshot())
        // No hay nada que predecir a futuro: los datos cambian cuando el
        // iPhone manda un snapshot, y ahí se fuerza la recarga. El refresco
        // por tiempo es solo una red de seguridad.
        let proxima = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entrada], policy: .after(proxima)))
    }
}

// MARK: - Complicación de alta rápida

/// Un (+) en la esfera que abre Fino directo en la pantalla de nuevo gasto.
/// Es la razón de ser de todo esto: dos toques desde levantar la muñeca
/// hasta tener el teclado numérico en pantalla.
struct AgregarGastoComplicacion: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "FinoAgregarGasto",
            provider: ProveedorComplicacion()
        ) { _ in
            VistaAgregarGasto()
                .widgetURL(PayloadWatch.Enlace.nuevoGasto)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Agregar gasto")
        .description("Un toque para cargar un gasto en Fino.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct VistaAgregarGasto: View {

    @Environment(\.widgetFamily) private var familia

    var body: some View {
        switch familia {
        case .accessoryCorner:
            Image(systemName: "plus")
                .font(.title3.bold())
                .widgetLabel("Gasto")
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
            }
        }
    }
}

// MARK: - Complicación de gastos del mes

/// Los números del mes de un vistazo. Toca y abre la dona.
struct GastosDelMesComplicacion: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "FinoGastosDelMes",
            provider: ProveedorComplicacion()
        ) { entrada in
            VistaGastosDelMes(entrada: entrada)
                .widgetURL(PayloadWatch.Enlace.resumen)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Gastos del mes")
        .description("Lo que llevás gastado este mes.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct VistaGastosDelMes: View {

    @Environment(\.widgetFamily) private var familia
    let entrada: EntradaComplicacion

    private var datos: SnapshotWatch? { entrada.snapshot }

    var body: some View {
        switch familia {
        case .accessoryInline:
            enLinea
        case .accessoryCircular:
            circular
        default:
            rectangular
        }
    }

    @ViewBuilder
    private var enLinea: some View {
        if let datos {
            Text("Gastos \(datos.formatearCorto(datos.gastos))")
        } else {
            Text("Fino: sin datos")
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                Text(datos.map { $0.formatearCorto($0.gastos) } ?? "—")
                    .font(.system(size: 12, weight: .semibold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let datos {
                Text(datos.mes.isEmpty ? String(localized: "Este mes") : datos.mes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(datos.formatear(datos.gastos))
                        .font(.headline)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                Text("Balance \(datos.formatearCorto(datos.balance))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Fino")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Abrí la app")
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
