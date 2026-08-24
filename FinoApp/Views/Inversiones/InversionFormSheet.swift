import SwiftUI
import SwiftData

/// Alta y edición de una tenencia.
///
/// El formulario cambia según el tipo: acciones y cripto se cargan con
/// cantidad y cotización, y plazos fijos y cuentas remuneradas con el
/// capital. Son dos maneras distintas de decir cuánto vale y pedir las
/// dos a todos obligaría a inventar una cantidad de 1 en los plazos fijos.
struct InversionFormSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto

    private let existente: Inversion?

    @State private var nombre: String
    @State private var tipo: TipoInversion
    @State private var donde: String
    @State private var moneda: Moneda
    @State private var cantidadTexto: String
    @State private var precioTexto: String
    @State private var montoTexto: String
    @State private var tasaTexto: String
    @State private var tieneVencimiento: Bool
    @State private var vencimiento: Date

    init(inversion: Inversion? = nil) {
        existente = inversion
        _nombre = State(initialValue: inversion?.nombre ?? "")
        _tipo = State(initialValue: inversion?.tipo ?? .accion)
        _donde = State(initialValue: inversion?.donde ?? "")
        _moneda = State(initialValue: inversion?.moneda ?? .usd)
        _cantidadTexto = State(initialValue: Self.texto(inversion?.cantidad))
        _precioTexto = State(initialValue: Self.texto(inversion?.precio))
        _montoTexto = State(initialValue: Self.texto(inversion?.monto))
        _tasaTexto = State(initialValue: Self.texto(inversion?.tasaAnual))
        _tieneVencimiento = State(initialValue: inversion?.vencimiento != nil)
        _vencimiento = State(initialValue: inversion?.vencimiento ?? .now)
    }

    private static func texto(_ valor: Double?) -> String {
        guard let valor else { return "" }
        return valor.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(valor))
            : String(format: "%g", valor)
    }

    private var cantidad: Double? { Formatters.parsearMonto(cantidadTexto) }
    private var precio: Double? { Formatters.parsearMonto(precioTexto) }
    private var monto: Double? { Formatters.parsearMonto(montoTexto) }

    /// Cuánto vale con lo cargado, para mostrarlo antes de guardar.
    private var valor: Double? {
        if tipo.usaTicker {
            guard let cantidad, let precio else { return nil }
            return cantidad * precio
        }
        return monto
    }

    private var esValido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && (valor ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Qué es") {
                    Picker("Tipo", selection: $tipo.animation()) {
                        ForEach(TipoInversion.allCases) { tipo in
                            Label(tipo.nombre, systemImage: tipo.icono).tag(tipo)
                        }
                    }

                    TextField(
                        tipo.usaTicker ? "Ticker (AAPL, BTC)" : "Nombre",
                        text: $nombre
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(tipo.usaTicker ? .characters : .words)

                    TextField("Dónde está (IBKR, Binance, Galicia)", text: $donde)
                        .autocorrectionDisabled()
                }

                Section {
                    Picker("Moneda", selection: $moneda) {
                        ForEach(Moneda.allCases) { moneda in
                            Text("\(moneda.simbolo) · \(moneda.rawValue)").tag(moneda)
                        }
                    }

                    if tipo.usaTicker {
                        HStack {
                            Text("Cantidad")
                            Spacer()
                            TextField("0", text: $cantidadTexto)
                                .keyboardType(.decimalPad)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                        HStack {
                            Text("Cotización")
                            Spacer()
                            Text(moneda.simbolo).foregroundStyle(.secondary)
                            TextField("0", text: $precioTexto)
                                .keyboardType(.decimalPad)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 110)
                        }
                    } else {
                        HStack {
                            Text("Capital")
                            Spacer()
                            Text(moneda.simbolo).foregroundStyle(.secondary)
                            TextField("0", text: $montoTexto)
                                .keyboardType(.decimalPad)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 130)
                        }
                    }

                    if let valor {
                        LabeledContent("Vale", value: Formatters.moneda(valor, moneda: moneda))
                            .font(.subheadline)
                    }
                } header: {
                    Text("Cuánto")
                } footer: {
                    if tipo.usaTicker {
                        Text("La cotización se carga a mano por ahora. El valor sale de multiplicarla por la cantidad.")
                    }
                }

                if tipo == .plazoFijo || tipo == .cuentaRemunerada {
                    Section {
                        HStack {
                            Text("Tasa anual")
                            Spacer()
                            TextField("0", text: $tasaTexto)
                                .keyboardType(.decimalPad)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("%").foregroundStyle(.secondary)
                        }
                        Toggle("Tiene vencimiento", isOn: $tieneVencimiento.animation())
                        if tieneVencimiento {
                            DatePicker("Vence", selection: $vencimiento, displayedComponents: .date)
                        }
                    } footer: {
                        Text("La tasa y el vencimiento no entran en ningún total: sirven para avisarte cuando esté por vencer.")
                    }
                }
            }
            .navigationTitle(existente == nil ? "Nueva inversión" : "Editar inversión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .fontWeight(.semibold)
                        .disabled(!esValido)
                }
            }
        }
    }

    private func guardar() {
        let inversion = existente ?? Inversion(nombre: nombre, tipo: tipo)
        inversion.nombre = nombre.trimmingCharacters(in: .whitespaces)
        inversion.tipoRaw = tipo.rawValue
        inversion.donde = donde.trimmingCharacters(in: .whitespaces)
        inversion.monedaRaw = moneda.rawValue

        // Solo se guarda la forma que corresponde al tipo: si cambiaste de
        // acción a plazo fijo, la cantidad vieja no debe quedar dando
        // vueltas y decidiendo el valor.
        if tipo.usaTicker {
            inversion.cantidad = cantidad
            inversion.precio = precio
            inversion.monto = nil
        } else {
            inversion.monto = monto
            inversion.cantidad = nil
            inversion.precio = nil
        }

        inversion.tasaAnual = Formatters.parsearMonto(tasaTexto)
        inversion.vencimiento = tieneVencimiento ? vencimiento : nil

        if existente == nil { contexto.insert(inversion) }
        try? contexto.save()
        Haptics.exito()
        dismiss()
    }
}
