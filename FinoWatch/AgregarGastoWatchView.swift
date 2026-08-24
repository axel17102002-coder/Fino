import SwiftUI
import WatchKit

/// Alta rápida de un gasto: monto y categoría, nada más.
///
/// Sin cuenta, sin cuotas, sin notas y sin fecha: son los campos que en la
/// muñeca cuestan más de lo que aportan. El movimiento llega al iPhone sin
/// cuenta asignada y se termina de completar ahí si hace falta.
struct AgregarGastoWatchView: View {

    @Environment(ConexionWatch.self) private var conexion

    @State private var monto: Double = 0
    @State private var ruta: [Paso] = []
    @State private var tecleando = false
    @FocusState private var coronaActiva: Bool

    /// Pasos del alta después del monto.
    private enum Paso: Hashable {
        case categoria
        case listo(monto: Double, nombre: String, colorHex: String)
    }

    private var datos: SnapshotWatch { conexion.datos }

    /// Cuánto mueve la corona por click. En pesos, de a 100; en monedas
    /// con centavos, de a 1.
    private var paso: Double { datos.decimales == 0 ? 100 : 1 }

    var body: some View {
        NavigationStack(path: $ruta) {
            pantallaMonto
                .navigationDestination(for: Paso.self) { paso in
                    switch paso {
                    case .categoria:
                        pantallaCategoria
                    case let .listo(monto, nombre, colorHex):
                        pantallaListo(monto: monto, nombre: nombre, colorHex: colorHex)
                    }
                }
        }
    }

    // MARK: - Monto

    private var pantallaMonto: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            Button {
                tecleando = true
            } label: {
                Text(datos.formatear(monto))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .foregroundStyle(monto > 0 ? Color.crema : .secondary)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
            }
            .buttonStyle(.plain)

            Text("Girá la corona o tocá el monto")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Button {
                ruta.append(.categoria)
            } label: {
                Text("Siguiente")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.verdeMarca)
            .disabled(monto <= 0)
        }
        .padding(.horizontal, 2)
        .focusable()
        .focused($coronaActiva)
        .digitalCrownRotation(
            $monto,
            from: 0,
            through: 100_000_000,
            by: paso,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear { coronaActiva = true }
        .navigationTitle("Nuevo gasto")
        .sheet(isPresented: $tecleando) {
            TecladoMonto(datos: datos) { valor in
                monto = valor
                tecleando = false
            }
        }
        .animation(.snappy(duration: 0.2), value: monto)
    }

    // MARK: - Categoría

    private var pantallaCategoria: some View {
        Group {
            if datos.categorias.isEmpty {
                ScrollView { SinDatosWatch().padding(.top, 16) }
            } else {
                List(datos.categorias) { categoria in
                    Button {
                        guardar(categoria)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: categoria.icono)
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color(hex: categoria.colorHex)))
                            Text(categoria.nombre)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Categoría")
    }

    private func guardar(_ categoria: SnapshotWatch.CategoriaDisponible) {
        conexion.cargar(monto: monto, categoria: categoria)
        WKInterfaceDevice.current().play(.success)
        ruta.append(.listo(
            monto: monto,
            nombre: categoria.nombre,
            colorHex: categoria.colorHex
        ))
    }

    // MARK: - Confirmación

    private func pantallaListo(monto: Double, nombre: String, colorHex: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color(hex: colorHex))

            Text(datos.formatear(monto))
                .font(.headline)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(nombre)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !conexion.alcanzable {
                Text("Llega al iPhone en cuanto esté cerca")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationBarBackButtonHidden()
        .task {
            // La pantalla se mira, no se toca: vuelve sola al monto.
            try? await Task.sleep(for: .seconds(1.8))
            reiniciar()
        }
    }

    private func reiniciar() {
        ruta.removeAll()
        monto = 0
    }
}

// MARK: - Teclado numérico

/// Teclado numérico propio para cargar el monto.
///
/// watchOS no tiene `.keyboardType`, así que un `TextField` siempre abre
/// el input del sistema —garabato, dictado o el teclado chico—, que para
/// tipear un número es carísimo. Este es un pad de dígitos común.
///
/// Los dígitos entran por la derecha, como en un posnet, y la coma la pone
/// sola la moneda: en pesos `5000` es `$ 5.000`, y en dólares `1234` es
/// `US$ 12,34`. Así no hace falta una tecla de separador decimal, que en
/// esta pantalla sería una tecla desperdiciada.
private struct TecladoMonto: View {

    let datos: SnapshotWatch
    let alConfirmar: (Double) -> Void

    @State private var digitos = ""

    /// Nueve dígitos cubren cualquier gasto y evitan que el número se
    /// desborde de la pantalla.
    private let maximoDigitos = 9

    private var valor: Double {
        let crudo = Double(digitos) ?? 0
        guard datos.decimales > 0 else { return crudo }
        return crudo / pow(10, Double(datos.decimales))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                Text(datos.formatear(valor))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .foregroundStyle(digitos.isEmpty ? .secondary : Color.crema)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                    .padding(.bottom, 2)

                fila(["1", "2", "3"])
                fila(["4", "5", "6"])
                fila(["7", "8", "9"])

                HStack(spacing: 4) {
                    tecla(icono: "delete.left", accion: borrar)
                    tecla(texto: "0") { agregar("0") }
                    tecla(icono: "checkmark", destacada: true) {
                        alConfirmar(valor)
                    }
                    .disabled(valor <= 0)
                    .opacity(valor > 0 ? 1 : 0.4)
                }
            }
            .padding(.horizontal, 2)
        }
        .animation(.snappy(duration: 0.15), value: digitos)
    }

    private func fila(_ numeros: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(numeros, id: \.self) { numero in
                tecla(texto: numero) { agregar(numero) }
            }
        }
    }

    private func tecla(
        texto: String? = nil,
        icono: String? = nil,
        destacada: Bool = false,
        accion: @escaping () -> Void
    ) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            accion()
        } label: {
            Group {
                if let texto {
                    Text(texto)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                } else if let icono {
                    Image(systemName: icono)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(destacada ? Color.verdeMarca : Color.white.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }

    private func agregar(_ digito: String) {
        guard digitos.count < maximoDigitos else { return }
        // Un cero adelante no aporta nada... salvo en monedas con centavos,
        // donde "05" es la única forma de escribir 0,05.
        if digitos.isEmpty && digito == "0" && datos.decimales == 0 { return }
        digitos.append(digito)
    }

    private func borrar() {
        guard !digitos.isEmpty else { return }
        digitos.removeLast()
    }
}
