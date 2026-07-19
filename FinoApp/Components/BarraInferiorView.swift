import SwiftUI

/// Forma de la barra inferior: rectángulo redondeado con una muesca
/// circular recortada en el centro del borde superior, donde reposa
/// el botón (+).
struct BarraConMuesca: Shape {
    var radioEsquinas: CGFloat = 31
    var radioMuesca: CGFloat = 36
    /// Posición vertical del centro de la muesca respecto del borde superior.
    var centroMuescaY: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let barra = CGPath(
            roundedRect: rect,
            cornerWidth: radioEsquinas,
            cornerHeight: radioEsquinas,
            transform: nil
        )
        let muesca = CGPath(
            ellipseIn: CGRect(
                x: rect.midX - radioMuesca,
                y: rect.minY + centroMuescaY - radioMuesca,
                width: radioMuesca * 2,
                height: radioMuesca * 2
            ),
            transform: nil
        )
        return Path(barra.subtracting(muesca))
    }
}

/// Barra de pestañas propia (reemplaza a la del sistema) con el botón (+)
/// integrado en una muesca circular, como una cuna.
struct BarraInferiorView: View {
    @Binding var seleccion: RootTabView.Pestania
    /// Se llama cada vez que se toca "Inicio", esté donde esté el usuario:
    /// permite volver el Dashboard a su raíz.
    var alTocarInicio: () -> Void = {}
    let accionAgregar: () -> Void

    private let alturaBarra: CGFloat = 62
    private let diametroBoton: CGFloat = 58

    var body: some View {
        ZStack(alignment: .top) {
            // Cada lado va agrupado y con el mismo ancho, así el hueco del
            // botón (+) queda centrado aunque haya distinta cantidad de ítems.
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    item(.inicio, String(localized: "Inicio"), "house.fill")
                    item(.movimientos, String(localized: "Movimientos"), "list.bullet.rectangle.fill")
                }
                .frame(maxWidth: .infinity)
                Color.clear
                    .frame(width: diametroBoton + 18, height: 1)
                HStack(spacing: 0) {
                    item(.estadisticas, String(localized: "Estadísticas"), "chart.bar.xaxis")
                    item(.configuracion, String(localized: "Configuración"), "gearshape.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: alturaBarra)
            .modifier(FondoBarraConMuesca())

            FloatingActionButton(accion: accionAgregar)
                .offset(y: -diametroBoton / 2)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private func item(
        _ pestania: RootTabView.Pestania,
        _ titulo: String,
        _ icono: String
    ) -> some View {
        Button {
            if pestania == .inicio { alTocarInicio() }
            seleccion = pestania
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icono)
                    .font(.system(size: 19, weight: .medium))
                Text(titulo)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(seleccion == pestania ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titulo)
        .accessibilityAddTraits(seleccion == pestania ? [.isSelected] : [])
    }
}

/// Liquid Glass nativo en iOS 26+ con la forma recortada; en versiones
/// anteriores, material translúcido con la misma silueta.
private struct FondoBarraConMuesca: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: BarraConMuesca())
        } else {
            content
                .background(.ultraThinMaterial, in: BarraConMuesca())
                .overlay {
                    BarraConMuesca()
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}
