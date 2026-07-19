import SwiftUI
import SwiftData
import UserNotifications

/// Preferencias de la app: general, finanzas, seguridad y acerca de.
/// El backup y la gestión de datos viven en su propia pestaña (`DatosView`).
struct ConfiguracionView: View {

    @AppStorage(Preferencias.claveMoneda) private var monedaRaw: String = Moneda.ars.rawValue
    @AppStorage(Preferencias.claveTema) private var temaRaw: String = TemaApp.automatico.rawValue
    @AppStorage(Preferencias.claveNombre) private var nombre: String = ""
    @AppStorage(Preferencias.claveBloqueoBiometrico) private var bloqueoActivado = false
    @AppStorage(Preferencias.claveDiaInicioMes) private var diaInicioMes = 1
    @AppStorage(Preferencias.claveRedondeoActivado) private var redondeoActivado = false
    @AppStorage(Preferencias.claveRedondeoObjetivoID) private var redondeoObjetivoID = ""
    @AppStorage(Preferencias.claveRedondeoPaso) private var redondeoPaso = 1000.0
    @AppStorage(Preferencias.claveTotalRedondeado) private var totalRedondeado = 0.0
    @AppStorage(Preferencias.claveMontosOcultos) private var montosOcultos = false

    @State private var permisoNotificaciones: UNAuthorizationStatus = .notDetermined
    @State private var avisosProgramados = 0

    @Query private var movimientos: [Movimiento]
    @Query(sort: \ObjetivoAhorro.creado) private var objetivos: [ObjetivoAhorro]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Título propio en blanco: el título grande del sistema
                // toma el color del tema y se pierde sobre el fondo verde.
                Text("Configuración")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Form {
                    seccionGeneral
                    seccionFinanzas
                    seccionRedondeo
                    seccionNotificaciones
                    seccionDatos
                    seccionSeguridad
                    seccionAcercaDe
                }
                .scrollContentBackground(.hidden)
                // Deja pasar el último renglón por encima de la barra
                // inferior flotante (62 de barra + margen).
                .contentMargins(.bottom, 84, for: .scrollContent)
            }
            .background(Color.fondoPantalla)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Secciones

    /// Perfil, apariencia y moneda en un solo grupo.
    private var seccionGeneral: some View {
        Section {
            TextField("Tu nombre", text: $nombre)
                .textContentType(.givenName)
            Picker("Tema", selection: $temaRaw) {
                ForEach(TemaApp.allCases) { tema in
                    Label(tema.nombre, systemImage: tema.icono).tag(tema.rawValue)
                }
            }
            Picker("Moneda", selection: $monedaRaw) {
                ForEach(Moneda.allCases) { moneda in
                    Text("\(moneda.simbolo) · \(moneda.nombre)").tag(moneda.rawValue)
                }
            }
            Toggle(isOn: $montosOcultos) {
                Label("Ocultar montos", systemImage: montosOcultos ? "eye.slash.fill" : "eye.fill")
            }
        } header: {
            textoSobreFondo("General")
        } footer: {
            textoSobreFondo("El nombre se usa para saludarte y el tema cambia el color de las tarjetas.", esFooter: true)
        }
    }

    /// Categorías, recurrentes y mes financiero: todo lo que define
    /// cómo se organizan tus finanzas.
    private var seccionFinanzas: some View {
        Section {
            NavigationLink {
                CategoriasView()
            } label: {
                Label("Editar categorías", systemImage: "tag.fill")
            }
            NavigationLink {
                RecurrentesView()
            } label: {
                Label("Movimientos recurrentes", systemImage: "arrow.triangle.2.circlepath")
            }
            NavigationLink {
                DeudasView()
            } label: {
                Label("Me deben", systemImage: "person.2.fill")
            }
            Picker("El mes empieza el día", selection: $diaInicioMes) {
                ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
            }
        } header: {
            textoSobreFondo("Finanzas")
        } footer: {
            textoSobreFondo("Los recurrentes se cargan solos cada mes. Y si cobrás el 5, poné 5: el resumen, los presupuestos y los promedios van del 5 al 4 del mes siguiente.", esFooter: true)
        }
    }

    /// Redondeo automático de gastos hacia un objetivo de ahorro.
    @ViewBuilder
    private var seccionRedondeo: some View {
        if !objetivos.isEmpty {
            Section {
                Toggle(isOn: $redondeoActivado.animation()) {
                    Label("Redondear gastos a una meta", systemImage: "arrow.up.circle.fill")
                }
                if redondeoActivado {
                    Picker("Meta", selection: $redondeoObjetivoID) {
                        Text("Elegí una").tag("")
                        ForEach(objetivos) { objetivo in
                            Label(objetivo.nombre, systemImage: objetivo.icono)
                                .tag(objetivo.id.uuidString)
                        }
                    }
                    Picker("Redondear a", selection: $redondeoPaso) {
                        ForEach([100.0, 500.0, 1000.0], id: \.self) { paso in
                            Text(paso.enMonedaCompacta).tag(paso)
                        }
                    }
                }
            } header: {
                textoSobreFondo("Ahorro invisible")
            } footer: {
                if totalRedondeado > 0 {
                    textoSobreFondo("Cada gasto se redondea y el vuelto va a tu meta. Ya juntaste \(totalRedondeado.enMoneda) sin darte cuenta.", esFooter: true)
                } else {
                    textoSobreFondo("Cada gasto se redondea al valor elegido y la diferencia se aporta sola a tu meta. Gastás $4.320 → $680 van a la meta.", esFooter: true)
                }
            }
        }
    }
    /// Estado de las notificaciones: sin permiso, todos los avisos de la
    /// app (vencimientos, presupuestos, backup) fallan en silencio.
    @ViewBuilder
    private var seccionNotificaciones: some View {
        Section {
            switch permisoNotificaciones {
            case .authorized, .provisional, .ephemeral:
                LabeledContent {
                    Text("\(avisosProgramados)")
                        .monospacedDigit()
                } label: {
                    Label("Avisos activados", systemImage: "bell.badge.fill")
                        .foregroundStyle(Color.green.legible())
                }
            case .denied:
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Activar en Ajustes de iOS", systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                }
            default:
                Button {
                    Task {
                        await NotificacionesService.pedirPermiso()
                        await revisarNotificaciones()
                    }
                } label: {
                    Label("Activar notificaciones", systemImage: "bell")
                }
            }
        } header: {
            textoSobreFondo("Notificaciones")
        } footer: {
            switch permisoNotificaciones {
            case .denied:
                textoSobreFondo("Están bloqueadas en iOS: sin ellas no vas a recibir los avisos de vencimiento de tarjetas, presupuestos ni backup.", esFooter: true)
            case .authorized, .provisional, .ephemeral:
                textoSobreFondo("Te avisamos el día antes de cada vencimiento de tarjeta, al llegar al 80% y 100% de un presupuesto, y para recordarte el backup.", esFooter: true)
            default:
                textoSobreFondo("Activalas para recibir los vencimientos de tarjetas, las alertas de presupuesto y el recordatorio de backup.", esFooter: true)
            }
        }
        .task { await revisarNotificaciones() }
    }

    private func revisarNotificaciones() async {
        permisoNotificaciones = await NotificacionesService.estadoPermiso()
        avisosProgramados = await NotificacionesService.programadas()
    }

    /// Acceso a la pantalla de backup y gestión de datos.
    private var seccionDatos: some View {
        Section {
            LabeledContent("Movimientos guardados", value: "\(movimientos.count)")
            NavigationLink {
                DatosView()
            } label: {
                Label("Datos y backup", systemImage: "externaldrive.fill")
            }
        } header: {
            textoSobreFondo("Datos")
        } footer: {
            textoSobreFondo("Backup completo, exportación CSV y borrado de datos.", esFooter: true)
        }
    }

    private var seccionSeguridad: some View {
        Section {
            Toggle(isOn: $bloqueoActivado) {
                Label("Bloquear con Face ID", systemImage: "faceid")
            }
        } header: {
            textoSobreFondo("Seguridad")
        } footer: {
            textoSobreFondo("Al volver a abrir la app te va a pedir Face ID (o el código del teléfono).", esFooter: true)
        }
    }

    /// Encabezados y pies de sección legibles sobre el fondo verde.
    /// Recibe `LocalizedStringKey` para que los textos entren al catálogo.
    private func textoSobreFondo(_ texto: LocalizedStringKey, esFooter: Bool = false) -> some View {
        Text(texto)
            .foregroundStyle(.white.opacity(esFooter ? 0.7 : 0.85))
    }

    private var seccionAcercaDe: some View {
        Section {
            LabeledContent("Versión", value: "1.2")
            LabeledContent("Hecho con", value: "SwiftUI + SwiftData")
        } header: {
            textoSobreFondo("Acerca de")
        }
    }

}

#Preview {
    ConfiguracionView()
        .modelContainer(for: [Movimiento.self, Cuenta.self], inMemory: true)
}
