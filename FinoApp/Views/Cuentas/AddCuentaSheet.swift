import SwiftUI
import SwiftData

/// Formulario de alta y edición de cuentas, billeteras y tarjetas de crédito.
struct AddCuentaSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto

    /// Cuenta que se está editando; `nil` cuando es un alta.
    let cuentaEditada: Cuenta?

    @State private var tipo: TipoCuenta
    @State private var nombre: String
    @State private var banco: String
    @State private var colorHex: String
    @State private var ultimosDigitos: String
    @State private var limiteTexto: String
    @State private var diaCierre: Int
    @State private var diaVencimiento: Int
    @State private var saldoInicialTexto: String

    private static let paleta = Paleta.colores

    init(cuenta: Cuenta? = nil) {
        cuentaEditada = cuenta
        _tipo = State(initialValue: cuenta?.tipo ?? .cuentaBancaria)
        _nombre = State(initialValue: cuenta?.nombre ?? "")
        _banco = State(initialValue: cuenta?.banco ?? "")
        _colorHex = State(initialValue: cuenta?.colorHex ?? "6366F1")
        _ultimosDigitos = State(initialValue: cuenta?.ultimosDigitos ?? "")
        _limiteTexto = State(initialValue: {
            guard let limite = cuenta?.limite, limite > 0 else { return "" }
            return String(format: "%.0f", limite)
        }())
        _diaCierre = State(initialValue: {
            guard let dia = cuenta?.diaCierre, dia > 0 else { return 25 }
            return dia
        }())
        _diaVencimiento = State(initialValue: {
            guard let dia = cuenta?.diaVencimiento, dia > 0 else { return 7 }
            return dia
        }())
        _saldoInicialTexto = State(initialValue: {
            guard let cuenta, !cuenta.esTarjetaCredito, cuenta.saldoInicial != 0 else { return "" }
            return String(format: "%.0f", cuenta.saldoInicial)
        }())
    }

    private var esValida: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $tipo) {
                        ForEach(TipoCuenta.allCases) { tipo in
                            Label(tipo.nombre, systemImage: tipo.icono).tag(tipo)
                        }
                    }
                    // Cambiar el tipo de una cuenta existente rompería sus
                    // movimientos y consumos, por eso se bloquea.
                    .disabled(cuentaEditada != nil)
                }

                Section("Datos") {
                    TextField("Nombre (ej: Galicia Visa)", text: $nombre)
                    if tipo == .cuentaBancaria || tipo == .tarjetaCredito {
                        TextField("Banco", text: $banco)
                    }
                }

                if tipo == .tarjetaCredito {
                    Section("Tarjeta") {
                        TextField("Últimos 4 dígitos", text: $ultimosDigitos)
                            .keyboardType(.numberPad)
                            .onChange(of: ultimosDigitos) { _, nuevo in
                                ultimosDigitos = String(nuevo.filter(\.isNumber).prefix(4))
                            }
                        HStack {
                            Text("Límite")
                            Spacer()
                            TextField("Opcional", text: $limiteTexto)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("Día de cierre", selection: $diaCierre) {
                            ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                        }
                        Picker("Día de vencimiento", selection: $diaVencimiento) {
                            ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                        }
                    }
                } else {
                    Section("Saldo") {
                        HStack {
                            Text("Saldo inicial")
                            Spacer()
                            TextField("0", text: $saldoInicialTexto)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(Self.paleta, id: \.self) { hex in
                            Button {
                                colorHex = hex
                                Haptics.seleccion()
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if colorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(cuentaEditada == nil ? "Nueva cuenta" : "Editar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .fontWeight(.semibold)
                        .disabled(!esValida)
                }
            }
        }
    }

    private func guardar() {
        let esTarjeta = tipo == .tarjetaCredito

        if let cuenta = cuentaEditada {
            cuenta.nombre = nombre.trimmingCharacters(in: .whitespaces)
            cuenta.banco = banco.trimmingCharacters(in: .whitespaces)
            cuenta.colorHex = colorHex
            cuenta.ultimosDigitos = esTarjeta ? ultimosDigitos : ""
            cuenta.limite = esTarjeta ? (Formatters.parsearMonto(limiteTexto) ?? 0) : 0
            cuenta.diaCierre = esTarjeta ? diaCierre : 0
            cuenta.diaVencimiento = esTarjeta ? diaVencimiento : 0
            cuenta.saldoInicial = esTarjeta ? 0 : (Formatters.parsearMonto(saldoInicialTexto) ?? 0)
        } else {
            let nueva = Cuenta(
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                tipo: tipo,
                banco: banco.trimmingCharacters(in: .whitespaces),
                colorHex: colorHex,
                ultimosDigitos: esTarjeta ? ultimosDigitos : "",
                limite: esTarjeta ? (Formatters.parsearMonto(limiteTexto) ?? 0) : 0,
                diaCierre: esTarjeta ? diaCierre : 0,
                diaVencimiento: esTarjeta ? diaVencimiento : 0,
                saldoInicial: esTarjeta ? 0 : (Formatters.parsearMonto(saldoInicialTexto) ?? 0)
            )
            // Va al final de la lista, respetando el orden elegido.
            let existentes = (try? contexto.fetch(FetchDescriptor<Cuenta>())) ?? []
            nueva.orden = (existentes.map(\.orden).max() ?? -1) + 1
            contexto.insert(nueva)
        }
        try? contexto.save()
        Haptics.exito()
        dismiss()
    }
}

#Preview {
    AddCuentaSheet()
        .modelContainer(for: [Cuenta.self], inMemory: true)
}
