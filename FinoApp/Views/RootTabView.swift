import SwiftUI
import SwiftData

/// Contenedor principal de navegación de la app.
struct RootTabView: View {

    enum Pestania: String, Hashable {
        case inicio, movimientos, estadisticas, configuracion
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var contexto
    @Query private var movimientos: [Movimiento]

    @AppStorage(Preferencias.claveOnboardingCompletado) private var onboardingCompletado = false

    @State private var pestaniaActiva: Pestania = .inicio
    @State private var mostrandoMenuAlta = false
    @State private var mostrandoAlta = false
    @State private var mostrandoAporte = false

    init() {
        // Permite abrir la app en otra pestaña con el argumento de
        // lanzamiento `-pestaniaInicial <nombre>` (para pruebas).
        if let raw = UserDefaults.standard.string(forKey: "pestaniaInicial"),
           let pestania = Pestania(rawValue: raw) {
            _pestaniaActiva = State(initialValue: pestania)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $pestaniaActiva) {
                Tab("Inicio", systemImage: "house.fill", value: Pestania.inicio) {
                    DashboardView()
                        .toolbar(.hidden, for: .tabBar)
                }
                Tab("Movimientos", systemImage: "list.bullet.rectangle.fill", value: Pestania.movimientos) {
                    MovimientosView()
                        .toolbar(.hidden, for: .tabBar)
                }
                Tab("Estadísticas", systemImage: "chart.bar.xaxis", value: Pestania.estadisticas) {
                    EstadisticasView()
                        .toolbar(.hidden, for: .tabBar)
                }
                Tab("Configuración", systemImage: "gearshape.fill", value: Pestania.configuracion) {
                    ConfiguracionView()
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .sensoryFeedback(.selection, trigger: pestaniaActiva)
            // Reserva el alto de la barra propia para que el contenido
            // de las pestañas no quede tapado detrás de ella.
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 70)
            }

            BarraInferiorView(seleccion: $pestaniaActiva) { mostrandoMenuAlta = true }
        }
        .confirmationDialog("¿Qué querés hacer?", isPresented: $mostrandoMenuAlta, titleVisibility: .visible) {
            Button("Nuevo movimiento") { mostrandoAlta = true }
            Button("Aportar a una meta") { mostrandoAporte = true }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $mostrandoAlta) {
            AddTransactionSheet()
        }
        .sheet(isPresented: $mostrandoAporte) {
            AportarObjetivoSheet()
        }
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompletado },
            set: { _ in }
        )) {
            OnboardingView()
        }
        .task {
            RecurrentesService.generarPendientes(en: contexto)
            WidgetDataService.publicar(movimientos: movimientos)
        }
        // El intent "Agregar gasto" (Atajos / botón de acción) pide abrir
        // el formulario apenas la app está en pantalla.
        .onChange(of: AccionesRapidas.shared.abrirAltaMovimiento) { _, abrir in
            if abrir {
                mostrandoAlta = true
                AccionesRapidas.shared.abrirAltaMovimiento = false
            }
        }
        // El botón (+) del widget abre el formulario vía fino://nueva.
        .onOpenURL { url in
            if url.host == "nueva" {
                mostrandoAlta = true
            }
        }
        // Cualquier alta o baja de movimientos refresca el widget al toque
        // (la Query se actualiza sola ante cambios en la base).
        .onChange(of: movimientos) { _, nuevos in
            WidgetDataService.publicar(movimientos: nuevos)
        }
        .onChange(of: scenePhase) { _, fase in
            // Al salir de la app se actualiza el widget con los datos frescos.
            // Esto también cubre ediciones de montos, que no cambian la Query.
            if fase == .background {
                WidgetDataService.publicar(movimientos: movimientos)
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(
            for: [Movimiento.self, Cuenta.self, Presupuesto.self, ObjetivoAhorro.self],
            inMemory: true
        )
}
