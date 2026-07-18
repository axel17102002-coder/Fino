import SwiftUI
import SwiftData

@main
struct FinoApp: App {

    @AppStorage(Preferencias.claveTema) private var temaRaw: String = TemaApp.automatico.rawValue
    @AppStorage(Preferencias.claveBloqueoBiometrico) private var bloqueoActivado = false
    @Environment(\.scenePhase) private var scenePhase

    /// Arranca bloqueada si el usuario tiene el bloqueo activado.
    @State private var bloqueada = UserDefaults.standard.bool(forKey: Preferencias.claveBloqueoBiometrico)

    /// Momento en que la app pasó a segundo plano. Las salidas más cortas
    /// que `gracia` no piden Face ID de nuevo (saltos rápidos a otra app,
    /// alertas del sistema, llamadas).
    @State private var enSegundoPlanoDesde: Date?

    private let gracia: TimeInterval = 30

    private var tema: TemaApp { TemaApp(rawValue: temaRaw) ?? .automatico }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    // El id fuerza el redibujado completo al cambiar el
                    // tema: el fondo (verde u oscuro) se lee al construir
                    // cada vista.
                    .id(temaRaw)
                    .preferredColorScheme(tema.esquema)
                if bloqueada {
                    PantallaBloqueo { bloqueada = false }
                        .transition(.opacity)
                } else if bloqueoActivado && scenePhase != .active {
                    // Tapa el contenido en el visor de apps durante la gracia,
                    // sin pedir Face ID.
                    cortinaPrivacidad
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: scenePhase)
            .onChange(of: scenePhase) { _, fase in
                guard bloqueoActivado else { return }
                switch fase {
                case .background:
                    if enSegundoPlanoDesde == nil {
                        enSegundoPlanoDesde = .now
                    }
                case .active:
                    if let desde = enSegundoPlanoDesde,
                       Date.now.timeIntervalSince(desde) > gracia {
                        bloqueada = true
                    }
                    enSegundoPlanoDesde = nil
                default:
                    break
                }
            }
        }
        .modelContainer(PersistenceService.shared.container)
    }

    private var cortinaPrivacidad: some View {
        ZStack {
            Color.fondoPantalla.ignoresSafeArea()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 220)
        }
    }
}
