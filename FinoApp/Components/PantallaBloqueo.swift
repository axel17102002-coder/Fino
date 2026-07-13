import SwiftUI
import LocalAuthentication

/// Pantalla que cubre la app cuando el bloqueo biométrico está activado.
struct PantallaBloqueo: View {

    let alDesbloquear: () -> Void

    @State private var intentando = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 220)
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                Text("Fino está bloqueado")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            Button {
                Task { await autenticar() }
            } label: {
                Label("Desbloquear", systemImage: "faceid")
                    .font(.headline)
                    .foregroundStyle(Color.verdeMarca)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.white))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.verdeMarca.ignoresSafeArea())
        .task { await autenticar() }
    }

    private func autenticar() async {
        guard !intentando else { return }
        intentando = true
        defer { intentando = false }

        let contexto = LAContext()
        var error: NSError?
        // Si el dispositivo no tiene Face ID ni código, no se puede bloquear.
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            alDesbloquear()
            return
        }
        let exito = (try? await contexto.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Desbloquear tus finanzas"
        )) ?? false
        if exito {
            Haptics.exito()
            alDesbloquear()
        }
    }
}
