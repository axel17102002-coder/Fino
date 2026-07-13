import WidgetKit
import SwiftUI

/// Copia del struct que publica la app en el App Group.
/// Si cambian los campos, actualizar también `WidgetDataService.swift`.


struct ResumenEntry: TimelineEntry {
    let date: Date
    let resumen: ResumenParaWidget?
}

struct ResumenProvider: TimelineProvider {

    private static let grupo = "group.com.axelmorano.FinoApp"
    private static let clave = "resumenWidget"

    private func resumenGuardado() -> ResumenParaWidget? {
        guard let data = UserDefaults(suiteName: Self.grupo)?.data(forKey: Self.clave) else {
            return nil
        }
        return try? JSONDecoder().decode(ResumenParaWidget.self, from: data)
    }

    private var ejemplo: ResumenParaWidget {
        ResumenParaWidget(
            mes: "Julio 2026", balance: 647_800, gastos: 1_900_000,
            ingresos: 2_500_000, cashback: 48_000, simboloMoneda: "$"
        )
    }

    func placeholder(in context: Context) -> ResumenEntry {
        ResumenEntry(date: .now, resumen: ejemplo)
    }

    func getSnapshot(in context: Context, completion: @escaping (ResumenEntry) -> Void) {
        completion(ResumenEntry(date: .now, resumen: resumenGuardado() ?? ejemplo))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ResumenEntry>) -> Void) {
        let entrada = ResumenEntry(date: .now, resumen: resumenGuardado())
        let proxima = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entrada], policy: .after(proxima)))
    }
}

/// Widget con el resumen del mes: balance, gastos, ingresos y cashback.
struct ResumenMesWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ResumenMesWidget", provider: ResumenProvider()) { entry in
            ResumenMesView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0x36 / 255, green: 0x67 / 255, blue: 0x59 / 255)
                }
        }
        .configurationDisplayName("Resumen del mes")
        .description("Tu balance, gastos e ingresos del mes de un vistazo.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ResumenMesView: View {

    @Environment(\.widgetFamily) private var familia
    let entry: ResumenEntry

    var body: some View {
        if let resumen = entry.resumen {
            switch familia {
            case .systemMedium: mediano(resumen)
            default: chico(resumen)
            }
        } else {
            Text("Abrí Fino para cargar tus datos")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    private func chico(_ resumen: ResumenParaWidget) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(resumen.mes)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
            Text("Balance")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            Text(formateado(resumen.balance, simbolo: resumen.simboloMoneda))
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.bold())
                Text(formateado(resumen.gastos, simbolo: resumen.simboloMoneda))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color(red: 1, green: 0.62, blue: 0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediano(_ resumen: ResumenParaWidget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text("Balance de \(resumen.mes.lowercased())")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(formateado(resumen.balance, simbolo: resumen.simboloMoneda))
                    .font(.headline.bold())
                    .monospacedDigit()
                    .foregroundStyle(.white)
                // Abre el formulario de nueva transacción en la app.
                Link(destination: URL(string: "fino://nueva")!) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0x36 / 255, green: 0x67 / 255, blue: 0x59 / 255))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color(red: 1, green: 0.906, blue: 0.761)))
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                indicador(String(localized: "Gastos"), monto: resumen.gastos, simbolo: resumen.simboloMoneda,
                          icono: "arrow.up.right", color: Color(red: 1, green: 0.62, blue: 0.6))
                indicador(String(localized: "Ingresos"), monto: resumen.ingresos, simbolo: resumen.simboloMoneda,
                          icono: "arrow.down.left", color: Color(red: 0.6, green: 0.9, blue: 0.65))
                indicador(String(localized: "Cashback"), monto: resumen.cashback, simbolo: resumen.simboloMoneda,
                          icono: "percent", color: Color(red: 1, green: 0.8, blue: 0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func indicador(
        _ titulo: String, monto: Double, simbolo: String, icono: String, color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icono)
                    .font(.system(size: 8, weight: .bold))
                Text(titulo)
                    .font(.caption2)
            }
            .foregroundStyle(color)
            Text(formateado(monto, simbolo: simbolo))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.12)))
    }

    private func formateado(_ monto: Double, simbolo: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale.current
        let numero = formatter.string(from: NSNumber(value: monto)) ?? "0"
        return "\(simbolo) \(numero)"
    }
}

// MARK: - Widget de gasto rápido

struct EntradaSimple: TimelineEntry {
    let date: Date
}

/// Provider sin datos: este widget es solo un acceso directo.
struct AgregarGastoProvider: TimelineProvider {
    func placeholder(in context: Context) -> EntradaSimple {
        EntradaSimple(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (EntradaSimple) -> Void) {
        completion(EntradaSimple(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntradaSimple>) -> Void) {
        completion(Timeline(entries: [EntradaSimple(date: .now)], policy: .never))
    }
}

/// Acceso directo al formulario de nuevo gasto, para la pantalla de
/// inicio (chico) y la pantalla de bloqueo (circular).
struct AgregarGastoWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AgregarGastoWidget", provider: AgregarGastoProvider()) { _ in
            AgregarGastoView()
                .containerBackground(for: .widget) {
                    Color(red: 0x36 / 255, green: 0x67 / 255, blue: 0x59 / 255)
                }
        }
        .configurationDisplayName("Agregar gasto")
        .description("Un toque para abrir el formulario de nuevo gasto.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct AgregarGastoView: View {

    @Environment(\.widgetFamily) private var familia

    var body: some View {
        Group {
            if familia == .accessoryCircular {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(red: 0x36 / 255, green: 0x67 / 255, blue: 0x59 / 255))
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(Color(red: 1, green: 0.906, blue: 0.761)))
                    Text("Nuevo gasto")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .widgetURL(URL(string: "fino://nueva"))
    }
}
