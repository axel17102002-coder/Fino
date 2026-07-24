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

extension View {
    /// Monta el contenido sobre una lámina con esquinas superiores
    /// redondeadas, dejando ver el verde de la base en los vértices, igual
    /// que la pantalla de inicio. Se usa junto a `BarraSuperior` sobre un
    /// fondo `Color.verdeOscuro`.
    ///
    /// Solo se redondea con el fondo (no se recorta el contenido): así el
    /// borde inferior se funde con la pantalla en vez de cortarse recto.
    func laminaRedondeada() -> some View {
        self.background(
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
                .fill(Color.fondoPantalla)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
