import SwiftUI
import SwiftData

/// Contenedor principal de navegación de la app.
struct RootTabView: View {

    enum Pestania: String, Hashable, CaseIterable {
        case inicio, movimientos, estadisticas, configuracion

        /// Posición en la barra: define hacia qué lado desliza la
        /// transición al cambiar de pestaña.
        var indice: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var contexto
    @Query private var movimientos: [Movimiento]

    @AppStorage(Preferencias.claveOnboardingCompletado) private var onboardingCompletado = false
    @AppStorage(Preferencias.claveMontosOcultos) private var montosOcultos = false

    @State private var pestaniaActiva: Pestania = .inicio
    /// Cambia con cada toque en "Inicio": recrea el Dashboard para que
    /// vuelva a su raíz aunque esté en una pantalla anidada (tarjeta, etc.).
    @State private var reinicioInicio = 0
    @State private var mostrandoMenuAlta = false
    @State private var mostrandoAlta = false
    @State private var mostrandoEscaner = false
    @State private var mostrandoAporte = false
    @State private var movimientoParaCategorizar: Movimiento?

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
            // Las cuatro pantallas quedan montadas y solo se muestra la
            // activa: así el cambio puede animarse y cada una conserva su
            // scroll y sus filtros, como hacía el TabView.
            ZStack {
                DashboardView()
                    .id(reinicioInicio)
                    .modifier(PantallaDePestania(indice: 0, activa: pestaniaActiva.indice))
                MovimientosView()
                    .modifier(PantallaDePestania(indice: 1, activa: pestaniaActiva.indice))
                EstadisticasView()
                    .modifier(PantallaDePestania(indice: 2, activa: pestaniaActiva.indice))
                ConfiguracionView()
                    .modifier(PantallaDePestania(indice: 3, activa: pestaniaActiva.indice))
            }
            .sensoryFeedback(.selection, trigger: pestaniaActiva)
            // El ojito de privacidad redibuja todas las pestañas: los
            // montos se formatean al construir cada vista.
            .id(montosOcultos)
            // Sin reserva de alto para la barra: reservarlo cortaba el
            // contenido 70pt antes del borde y dejaba abajo una franja del
            // color de fondo (negra en modo oscuro, verde en claro). Ahora
            // el contenido llega hasta el final y pasa por detrás del
            // vidrio. El aire para el último renglón lo dan los
            // `contentMargins` de cada lista.

            BarraInferiorView(
                seleccion: $pestaniaActiva,
                alTocarInicio: { reinicioInicio += 1 }
            ) { mostrandoMenuAlta = true }
        }
        .confirmationDialog("¿Qué querés hacer?", isPresented: $mostrandoMenuAlta, titleVisibility: .visible) {
            Button("Nuevo movimiento") { mostrandoAlta = true }
            Button("Aportar a una meta") { mostrandoAporte = true }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $mostrandoAlta) {
            AddTransactionSheet()
        }
        .sheet(isPresented: $mostrandoEscaner) {
            AddTransactionSheet(escanearAlAbrir: true)
        }
        .sheet(isPresented: $mostrandoAporte) {
            AportarObjetivoSheet()
        }
        .sheet(item: $movimientoParaCategorizar) { movimiento in
            AddTransactionSheet(movimiento: movimiento)
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
            NotificacionesService.programarVencimientosTarjetas(en: contexto)
            NotificacionesService.programarRecordatorioDiario()
            // Atajo del ícono que abrió la app desde cero: la señal ya
            // quedó marcada antes de que la vista la observe.
            if AccionesRapidas.shared.abrirAltaMovimiento {
                mostrandoAlta = true
                AccionesRapidas.shared.abrirAltaMovimiento = false
            }
            if AccionesRapidas.shared.escanearTicket {
                mostrandoEscaner = true
                AccionesRapidas.shared.escanearTicket = false
            }
            // Notificación "Revisá la categoría" tocada con la app cerrada.
            if let id = AccionesRapidas.shared.movimientoIdParaCategorizar {
                movimientoParaCategorizar = movimientos.first { $0.id == id }
                AccionesRapidas.shared.movimientoIdParaCategorizar = nil
            }
        }
        // El intent "Agregar gasto" (Atajos / botón de acción) pide abrir
        // el formulario apenas la app está en pantalla.
        .onChange(of: AccionesRapidas.shared.abrirAltaMovimiento) { _, abrir in
            if abrir {
                mostrandoAlta = true
                AccionesRapidas.shared.abrirAltaMovimiento = false
            }
        }
        // Quick Action "Escanear ticket" (mantener el ícono de la app).
        .onChange(of: AccionesRapidas.shared.escanearTicket) { _, escanear in
            if escanear {
                mostrandoEscaner = true
                AccionesRapidas.shared.escanearTicket = false
            }
        }
        // Notificación "Revisá la categoría" tocada con la app abierta o
        // en segundo plano.
        .onChange(of: AccionesRapidas.shared.movimientoIdParaCategorizar) { _, id in
            guard let id else { return }
            movimientoParaCategorizar = movimientos.first { $0.id == id }
            AccionesRapidas.shared.movimientoIdParaCategorizar = nil
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
                NotificacionesService.programarVencimientosTarjetas(en: contexto)
            }
        }
    }
}

/// Muestra la pestaña activa y desliza el cambio hacia el lado que
/// corresponde según el orden de la barra.
private struct PantallaDePestania: ViewModifier {
    let indice: Int
    let activa: Int

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var esActiva: Bool { indice == activa }

    func body(content: Content) -> some View {
        content
            .opacity(esActiva ? 1 : 0)
            .offset(x: esActiva ? 0 : (indice < activa ? -32 : 32))
            // Las ocultas no reciben toques ni las lee VoiceOver.
            .allowsHitTesting(esActiva)
            .accessibilityHidden(!esActiva)
            .animation(
                reducirMovimiento ? nil : .easeOut(duration: 0.22),
                value: activa
            )
    }
}

#Preview {
    RootTabView()
        .modelContainer(
            for: [Movimiento.self, Cuenta.self, Presupuesto.self, ObjetivoAhorro.self],
            inMemory: true
        )
}
