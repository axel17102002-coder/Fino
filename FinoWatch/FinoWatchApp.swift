import SwiftUI

/// Fino en la muñeca: una versión recortada de la app del iPhone.
///
/// Son tres pantallas y nada más: la dona de gastos del mes, el alta
/// rápida de un gasto y los últimos movimientos. Todo lo que necesita
/// pantalla grande (cuentas, tarjetas de crédito, cuotas, presupuestos,
/// estadísticas, escaneo de tickets) se queda en el iPhone.
@main
struct FinoWatchApp: App {

    @State private var conexion = ConexionWatch.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                // El alta trae su propio NavigationStack (monto →
                // categoría → confirmación); las otras dos lo necesitan
                // solo para que se vea el título arriba.
                NavigationStack { ResumenWatchView() }
                AgregarGastoWatchView()
                NavigationStack { UltimosWatchView() }
            }
            .tabViewStyle(.page)
            .environment(conexion)
            .task { conexion.activar() }
        }
    }
}

// MARK: - Estado vacío

/// Lo que se ve mientras el reloj nunca habló con el iPhone. Aparece en
/// las tres pantallas, así que vive suelto.
struct SinDatosWatch: View {

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(Color.crema)
            Text("Abrí Fino en el iPhone")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Con la app abierta y el reloj cerca se sincroniza solo.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)
    }
}
