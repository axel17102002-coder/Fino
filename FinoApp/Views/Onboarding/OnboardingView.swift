import SwiftUI
import SwiftData

/// Bienvenida de primera vez: nombre, moneda y datos de ejemplo opcionales.
struct OnboardingView: View {

    @Environment(\.modelContext) private var contexto

    @AppStorage(Preferencias.claveOnboardingCompletado) private var completado = false
    @AppStorage(Preferencias.claveNombre) private var nombre: String = ""
    @AppStorage(Preferencias.claveMoneda) private var monedaRaw: String = Moneda.ars.rawValue

    @State private var pagina = 0
    @State private var cargarEjemplo = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $pagina) {
                paginaBienvenida.tag(0)
                paginaNombre.tag(1)
                paginaMoneda.tag(2)
                paginaFinal.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if pagina < 3 {
                    withAnimation { pagina += 1 }
                } else {
                    terminar()
                }
                Haptics.impacto()
            } label: {
                Text(pagina < 3 ? "Continuar" : "Empezar")
                    .font(.headline)
                    .foregroundStyle(Color.verdeMarca)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.white))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.fondoPantalla.ignoresSafeArea())
    }

    // MARK: - Páginas

    private var paginaBienvenida: some View {
        pagina(icono: "leaf.fill", titulo: String(localized: "¡Bienvenido a Fino!")) {
            Text("Tu plata, clara y en un solo lugar: gastos, ingresos, tarjetas, presupuestos y objetivos.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var paginaNombre: some View {
        pagina(icono: "person.fill", titulo: String(localized: "¿Cómo te llamás?")) {
            VStack(spacing: 10) {
                TextField("", text: $nombre, prompt: Text("Tu nombre").foregroundStyle(.white.opacity(0.5)))
                    .textContentType(.givenName)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(.white.opacity(0.15)))
                    .padding(.horizontal, 32)

                Text("Es solo para saludarte. Podés cambiarlo cuando quieras en Configuración.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var paginaMoneda: some View {
        pagina(icono: "dollarsign.circle.fill", titulo: String(localized: "Tu moneda")) {
            VStack(spacing: 12) {
                ForEach(Moneda.allCases) { moneda in
                    Button {
                        monedaRaw = moneda.rawValue
                        Haptics.seleccion()
                    } label: {
                        HStack {
                            Text("\(moneda.simbolo) · \(moneda.nombre)")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if monedaRaw == moneda.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(.white.opacity(monedaRaw == moneda.rawValue ? 0.25 : 0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private var paginaFinal: some View {
        pagina(icono: "checkmark.seal.fill", titulo: String(localized: "¡Listo!")) {
            VStack(spacing: 16) {
                Text("Agregá tu primer movimiento con el botón + o explorá con datos de ejemplo.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))

                Toggle(isOn: $cargarEjemplo) {
                    Text("Cargar datos de ejemplo")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .tint(.white.opacity(0.4))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.12)))
                .padding(.horizontal, 32)
            }
        }
    }

    private func pagina<Contenido: View>(
        icono: String,
        titulo: String,
        @ViewBuilder contenido: () -> Contenido
    ) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: icono)
                .font(.system(size: 52))
                .foregroundStyle(.white)
            Text(titulo)
                .font(.title.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            contenido()
                .padding(.horizontal, 24)
            Spacer()
            Spacer()
        }
    }

    // MARK: - Acciones

    private func terminar() {
        if cargarEjemplo && !UserDefaults.standard.bool(forKey: Preferencias.claveDatosDemoCargados) {
            DatosDemo.insertar(en: contexto)
            UserDefaults.standard.set(true, forKey: Preferencias.claveDatosDemoCargados)
        }
        Task { await NotificacionesService.pedirPermiso() }
        Haptics.exito()
        completado = true
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Movimiento.self, Cuenta.self], inMemory: true)
}
