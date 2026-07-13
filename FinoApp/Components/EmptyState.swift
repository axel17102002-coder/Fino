import SwiftUI

/// Estado vacío reutilizable con ícono, mensaje y acción opcional.
/// Está pensado para mostrarse sobre el fondo verde de la app.
struct EmptyState: View {

    let icono: String
    let titulo: String
    let mensaje: String
    var tituloAccion: String? = nil
    var accion: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icono)
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 90, height: 90)
                .background(Circle().fill(.white.opacity(0.12)))

            Text(titulo)
                .font(.headline)
                .foregroundStyle(.white)

            Text(mensaje)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            if let tituloAccion, let accion {
                Button(action: accion) {
                    Text(tituloAccion)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.verdeMarca)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

#Preview {
    EmptyState(
        icono: "tray",
        titulo: String(localized: "Sin movimientos"),
        mensaje: String(localized: "Todavía no registraste ningún movimiento este mes."),
        tituloAccion: String(localized: "Agregar movimiento"),
        accion: {}
    )
    .frame(maxHeight: .infinity)
    .background(Color.fondoPantalla)
}
