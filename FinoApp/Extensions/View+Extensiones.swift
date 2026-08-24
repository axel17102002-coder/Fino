import SwiftUI
import UIKit

extension View {

    /// Estilo de tarjeta estándar de la app: fondo adaptativo, esquinas
    /// continuas bien redondeadas y sombra suave.
    func estiloTarjeta(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.fondoTarjeta)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            }
    }

    /// Igual que `estiloTarjeta` pero con vidrio: el material se aclara u
    /// oscurece solo según el modo, y por detrás se ve pasar el fondo.
    func estiloTarjetaVidrio(padding: CGFloat = 16) -> some View {
        modifier(TarjetaDeVidrio(padding: padding))
    }

    /// Vidrio teñido con el color propio del elemento. Es para las cards
    /// que se identifican por su color —cuentas y tarjetas—: se vuelven
    /// vidrio sin dejar de ser del color de cada una.
    func vidrioTenido(_ color: Color) -> some View {
        modifier(VidrioTenido(color: color))
    }

    /// Vidrio para las filas de una `List` agrupada, el equivalente de
    /// `estiloTarjetaVidrio` en las pantallas que son listas. Va fila por
    /// fila porque es la única forma de pintarlas, y la lista redondea
    /// sola las puntas de cada sección, así que el conjunto se lee como
    /// un panel.
    ///
    /// Acompañar siempre con `.scrollContentBackground(.hidden)` en la
    /// lista: si no, el fondo opaco del sistema queda por delante y no se
    /// ve nada del vidrio.
    func filaDeVidrio() -> some View {
        listRowBackground(FondoFilaVidrio())
    }
}

/// Liquid Glass nativo en iOS 26+; antes, material translúcido con la
/// misma silueta.
private struct TarjetaDeVidrio: ViewModifier {
    let padding: CGFloat

    private var forma: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            base(content).glassEffect(.regular, in: forma)
        } else {
            base(content)
                .background(.ultraThinMaterial, in: forma)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
    }

    /// Contenido y velo. Sin el velo la tarjeta se pierde: el vidrio en
    /// oscuro queda casi al ras del fondo (#121212) y en claro deja pasar
    /// el verde y le come contraste al texto.
    private func base(_ content: Content) -> some View {
        content
            .padding(padding)
            .background { forma.fill(velo) }
    }

    /// Blanco tenue que levanta el panel del fondo. En oscuro alcanza con
    /// un toque para que se lea como un vidrio apoyado encima; en claro
    /// hace falta más para que el texto no pelee con el verde de atrás.
    private var velo: Color {
        Color(uiColor: UIColor { traits in
            UIColor(white: 1, alpha: traits.userInterfaceStyle == .dark ? 0.1 : 0.35)
        })
    }
}

/// Fondo de una fila de lista. Va en `Rectangle` y no en una forma
/// redondeada: las filas se tocan entre sí y con esquinas propias se
/// verían como fichas sueltas en vez de un panel continuo. El recorte de
/// las puntas de la sección lo hace la lista.
///
/// Material y no `glassEffect`: el Liquid Glass dibuja su propio borde
/// iluminado, y con una fila atrás de la otra ese borde aparecía en cada
/// junta y la sección se veía como una pila de losas. El material no
/// tiene borde, así que las filas se funden en un panel solo.
private struct FondoFilaVidrio: View {
    var body: some View {
        velo.background(.ultraThinMaterial)
    }

    /// El mismo velo de las tarjetas, para que las filas y las cards
    /// tengan el mismo tono.
    private var velo: some View {
        Color(uiColor: UIColor { traits in
            UIColor(white: 1, alpha: traits.userInterfaceStyle == .dark ? 0.1 : 0.35)
        })
    }
}

/// Vidrio del color del elemento. El degradado propio queda debajo, algo
/// más suave que antes, y el vidrio teñido va encima: así la card sigue
/// siendo reconocible por su color pero refracta lo que tiene detrás.
private struct VidrioTenido: ViewModifier {
    let color: Color

    private var forma: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    func body(content: Content) -> some View {
        vidrio(content)
            .shadow(color: color.opacity(0.3), radius: 10, y: 5)
    }

    @ViewBuilder
    private func vidrio(_ content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background { forma.fill(degradado) }
                .glassEffect(.regular.tint(color.opacity(0.35)), in: forma)
        } else {
            // Sin Liquid Glass el degradado va entero: bajarlo sin material
            // que lo acompañe solo dejaría la card despintada.
            content.background { forma.fill(degradadoOpaco) }
        }
    }

    private var degradado: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.8), color.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var degradadoOpaco: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
