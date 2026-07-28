import SwiftUI

/// Franja superior verde de las pantallas principales: cubre el área del
/// reloj/notch con esquinas inferiores redondeadas, igual que la del Home.
/// Muestra el título de la pantalla y, opcionalmente, un botón de acción
/// a la derecha.
struct BarraSuperior<Trailing: View>: View {

    private let titulo: LocalizedStringKey
    private let trailing: Trailing

    init(_ titulo: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.titulo = titulo
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(titulo)
                .font(.title.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            trailing
        }
        .padding(.horizontal)
        .padding(.bottom, 11)
        .padding(.top, -3)
        .frame(maxWidth: .infinity)
        .frame(height: 45)
        .background(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24
            )
            .fill(Color.verdeOscuro)
            .ignoresSafeArea(edges: .top)
        )
    }
}

extension BarraSuperior where Trailing == EmptyView {
    /// Franja sin botón de acción (solo el título).
    init(_ titulo: LocalizedStringKey) {
        self.init(titulo) { EmptyView() }
    }
}

/// Recorte de la lámina: esquinas de arriba redondeadas y el borde de
/// abajo prolongado mucho más allá del marco.
///
/// Un `Shape` puede devolver un path más grande que el rect que recibe, y
/// acá se aprovecha eso: recortar con un rectángulo redondeado normal
/// resolvía las esquinas de arriba pero cortaba el contenido recto abajo,
/// dejando una franja del color de fondo contra el borde de la pantalla.
/// Estirando el path hacia abajo, el recorte solo actúa arriba.
private struct RecorteLamina: Shape {
    var radio: CGFloat = 26
    /// Suficiente para tapar cualquier alto de pantalla más el área segura.
    var excedenteInferior: CGFloat = 3000

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: radio,
            topTrailingRadius: radio,
            style: .continuous
        )
        .path(in: CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height + excedenteInferior
        ))
    }
}

extension View {
    /// Monta el contenido sobre una lámina con esquinas superiores
    /// redondeadas, dejando ver el verde de la base en los vértices, igual
    /// que la pantalla de inicio. Se usa junto a `BarraSuperior` sobre un
    /// fondo `Color.verdeOscuro`.
    ///
    /// El recorte llega hasta las esquinas de arriba y nada más: sin él, el
    /// contenido que scrollea se sale por encima de la curva; con un
    /// recorte común, el borde de abajo se corta recto contra la pantalla.
    func laminaRedondeada() -> some View {
        self
            .clipShape(RecorteLamina())
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
                    .fill(Color.fondoPantalla)
                    .ignoresSafeArea(edges: .bottom)
            )
    }
}
