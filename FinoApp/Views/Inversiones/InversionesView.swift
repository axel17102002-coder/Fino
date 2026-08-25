import SwiftUI
import SwiftData

/// Gestión de las tenencias: alta, edición y baja.
///
/// La card del Inicio muestra y no toca nada; acá se administran. Sin
/// esta pantalla se podían cargar pero no corregir ni borrar, que es
/// justo lo que más hace falta cuando cambia una cotización.
struct InversionesView: View {

    @Query(sort: \Inversion.orden) private var inversiones: [Inversion]
    @Environment(\.modelContext) private var contexto

    @State private var mostrandoAlta = false
    @State private var enEdicion: Inversion?
    @State private var tasasADolar: [Moneda: Double] = [:]
    @State private var actualizando = false
    @State private var resultado: String?

    /// Las que tienen precio que se puede consultar.
    private var conTicker: [Inversion] {
        inversiones.filter(\.tipo.usaTicker)
    }

    private var cartera: Cartera {
        Cartera(inversiones, tasasADolar: tasasADolar)
    }

    var body: some View {
        Group {
            if inversiones.isEmpty {
                EmptyState(
                    icono: "chart.pie",
                    titulo: String(localized: "Sin inversiones"),
                    mensaje: String(localized: "Cargá tus acciones, criptos y plazos fijos para tenerlos a mano."),
                    tituloAccion: String(localized: "Agregar inversión")
                ) {
                    mostrandoAlta = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                lista
            }
        }
        .background(Color.fondoPantalla.ignoresSafeArea())
        .navigationTitle("Inversiones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !conTicker.isEmpty {
                Button {
                    Task { await actualizarPrecios() }
                } label: {
                    if actualizando {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(actualizando)
                .accessibilityLabel("Actualizar cotizaciones")
            }

            Button {
                mostrandoAlta = true
                Haptics.seleccion()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Agregar inversión")
        }
        .sheet(isPresented: $mostrandoAlta) {
            InversionFormSheet()
        }
        .sheet(item: $enEdicion) { inversion in
            InversionFormSheet(inversion: inversion)
        }
        .task {
            tasasADolar = await Cartera.tasas(para: inversiones)
        }
    }

    private var lista: some View {
        List {
            Section {
                ForEach(cartera.ordenadas, id: \.inversion.id) { item in
                    fila(item.inversion, dolares: item.dolares)
                        .contentShape(Rectangle())
                        .onTapGesture { enEdicion = item.inversion }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                eliminar(item.inversion)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    Text("\(inversiones.count) tenencias")
                    Spacer()
                    Text(Formatters.moneda(cartera.total, moneda: .usd))
                        .monospacedDigit()
                }
                .textCase(nil)
            } footer: {
                if let resultado {
                    Text(resultado)
                } else if cartera.faltaCotizacion {
                    Text("Sin cotización del dólar no se pueden convertir las tenencias en pesos, así que no entran en el total.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func fila(_ inversion: Inversion, dolares: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: inversion.tipo.icono)
                .font(.subheadline)
                .foregroundStyle(inversion.tipo.color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(inversion.tipo.color.opacity(0.18)))

            VStack(alignment: .leading, spacing: 2) {
                Text(inversion.nombre)
                    .font(.subheadline.weight(.semibold))
                Text(detalle(de: inversion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(Formatters.moneda(dolares, moneda: .usd))
                .font(.callout.bold())
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    /// Tipo, dónde está y —en las de pesos— cuánto es en su moneda.
    private func detalle(de inversion: Inversion) -> String {
        var partes = [inversion.tipo.nombre]
        if !inversion.donde.isEmpty { partes.append(inversion.donde) }
        if inversion.moneda != .usd {
            partes.append(Formatters.moneda(inversion.valor, moneda: inversion.moneda))
        }
        if let actualizado = inversion.precioActualizado {
            partes.append(actualizado.formatted(.relative(presentation: .numeric)))
        }
        return partes.joined(separator: " · ")
    }

    /// Trae las cotizaciones y cuenta cuántas se pudieron actualizar.
    ///
    /// Dice cuántas fallaron en vez de fallar en silencio: si el ticker
    /// está mal escrito, la tenencia se queda con el precio viejo y sin
    /// aviso uno cree que se actualizó.
    private func actualizarPrecios() async {
        actualizando = true
        resultado = nil
        let total = conTicker.count
        let logradas = await CotizacionesService.actualizar(conTicker)
        try? contexto.save()
        tasasADolar = await Cartera.tasas(para: inversiones)
        actualizando = false
        resultado = logradas == total
            ? String(localized: "Cotizaciones actualizadas.")
            : String(localized: "Se actualizaron \(logradas) de \(total): revisá los tickers de las que faltan.")
        Haptics.exito()
    }

    private func eliminar(_ inversion: Inversion) {
        contexto.delete(inversion)
        try? contexto.save()
        Haptics.impacto()
    }
}
