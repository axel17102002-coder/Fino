import SwiftUI

/// Forma de la barra inferior: rectángulo redondeado con una muesca
/// circular recortada en el centro del borde superior, donde reposa
/// el botón (+).
struct BarraConMuesca: Shape {
    var radioEsquinas: CGFloat = 27 // modifica el redondeado
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

    private let alturaBarra: CGFloat = 58
    private let diametroBoton: CGFloat = 58

    /// Separación horizontal de la píldora respecto de las puntas de la
    /// barra, para que en Inicio y Configuración no quede pegada.
    static let margenPildora: CGFloat = 6

    /// Marco de cada pestaña dentro de la barra, para ubicar la píldora.
    @State private var marcos: [RootTabView.Pestania: CGRect] = [:]
    /// Posición del dedo mientras se arrastra la píldora.
    @State private var xArrastre: CGFloat?

    private static let espacioBarra = "barraInferior"

    var body: some View {
        ZStack(alignment: .top) {
            barra

            FloatingActionButton(accion: accionAgregar)
                .offset(y: -diametroBoton / 2)
        }
        .padding(.horizontal, 14)
        // Negativo para bajarla: come parte del margen sobre el indicador
        // de inicio, sin llegar a pisarlo.
        // Negativo para bajarla: se mete en el margen sobre el indicador de
        // inicio, dejándole aire suficiente para no pisarlo.
        .padding(.bottom, -10)
    }

    private var barra: some View {
        ZStack {
            // Vidrio de la barra + íconos, como una sola pieza ya compuesta.
            // La burbuja NO va acá adentro: envuelta por este vidrio se
            // apilaban dos capas y se veía como una mancha oscura en vez de
            // una lente. Afuera, toma esto de fondo y solo lo refracta.
            ZStack {
                // Cada lado va agrupado y con el mismo ancho, así el hueco del
                // botón (+) queda centrado aunque haya distinta cantidad de ítems.
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        item(.inicio, String(localized: "Inicio"))
                        item(.movimientos, String(localized: "Movimientos"))
                    }
                    .frame(maxWidth: .infinity)
                    Color.clear
                        .frame(width: diametroBoton + 18, height: 1)
                    HStack(spacing: 0) {
                        item(.estadisticas, String(localized: "Estadísticas"))
                        item(.configuracion, String(localized: "Configuración"))
                    }
                    .frame(maxWidth: .infinity)
                }
                // Margen mínimo para que la píldora no quede pegada a la
                // curva de la barra.
                .padding(.horizontal, Self.margenPildora)
            }
            .frame(height: alturaBarra)
            .modifier(FondoBarraConMuesca())

            // La burbuja va ENCIMA de los íconos: es lo que le deforma el
            // borde a los que va pasando, como en la referencia.
            pildoraSeleccion
                .allowsHitTesting(false)

            // Ícono activo redibujado ENCIMA de la burbuja. Es lo que hace
            // que adentro se vea nítido mientras el vidrio deforma a los
            // vecinos que le pasan por el borde.
            iconoActivoNitido
        }
        .frame(height: alturaBarra)
        .coordinateSpace(name: Self.espacioBarra)
        .onPreferenceChange(MarcosPestanias.self) { marcos = $0 }
        // Un único gesto atiende el toque y el arrastre: con botones
        // aparte, el arrastre les robaba el toque simple.
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.espacioBarra))
                .onChanged { valor in
                    xArrastre = valor.location.x
                    seleccionar(en: valor.location.x)
                }
                .onEnded { valor in
                    seleccionar(en: valor.location.x, esToque: true)
                    xArrastre = nil
                }
        )
    }

    /// Píldora de vidrio detrás de la pestaña activa. Ocupa la ranura
    /// entera —ícono y etiqueta van adentro— dejando un margen parejo
    /// contra la barra. Mientras se arrastra sigue al dedo.
    @ViewBuilder
    private var pildoraSeleccion: some View {
        if let marco = marcos[seleccion] {
            let arrastrando = xArrastre != nil
            Color.clear
                // En reposo queda contenida en la barra. Recién al apretar
                // crece y se asoma por arriba y por abajo: ahí el borde da
                // contra el contenido de la app y se ve la refracción.
                .frame(
                    width: marco.width,
                    height: arrastrando
                        ? alturaBarra + 14
                        : alturaBarra - Self.margenPildora * 2
                )
                .modifier(VidrioPildora(forma: Capsule(style: .continuous)))
                .scaleEffect(x: arrastrando ? 1.06 : 1)
                .position(x: xPildora(marcoActivo: marco), y: alturaBarra / 2)
                .animation(.spring(response: 0.32, dampingFraction: 0.72), value: seleccion)
                // El estirado se anima contra el booleano, NO contra la
                // posición del dedo: atado a `xArrastre` relanzaba un
                // spring en cada cuadro del gesto sobre una capa de
                // vidrio y la barra se sentía pesada. Así el seguimiento
                // del dedo va directo y solo se anima entrar y salir.
                .animation(.spring(response: 0.2, dampingFraction: 0.85), value: arrastrando)
        }
    }


    /// Centro de la píldora: el dedo mientras se arrastra (sin salirse de
    /// los extremos), o el centro de la pestaña activa al soltar.
    private func xPildora(marcoActivo: CGRect) -> CGFloat {
        guard let x = xArrastre else { return marcoActivo.midX }
        let centros = marcos.values.map(\.midX)
        guard let minimo = centros.min(), let maximo = centros.max() else { return marcoActivo.midX }
        return min(max(x, minimo), maximo)
    }

    private func pestaniaMasCercana(a x: CGFloat) -> RootTabView.Pestania? {
        marcos.min { abs($0.value.midX - x) < abs($1.value.midX - x) }?.key
    }

    /// Cambia a la pestaña que está bajo el dedo. `esToque` distingue el
    /// final del gesto, único momento en que "Inicio" vuelve a su raíz.
    private func seleccionar(en x: CGFloat, esToque: Bool = false) {
        guard let cercana = pestaniaMasCercana(a: x) else { return }
        if cercana != seleccion {
            seleccion = cercana
            Haptics.seleccion()
        } else if esToque && cercana == .inicio {
            alTocarInicio()
        }
    }

    /// Única fuente del ícono de cada pestaña: lo usan tanto el ítem de la
    /// fila como la copia nítida que va sobre la burbuja.
    ///
    /// Contorno en reposo y relleno en la activa. Antes eran todas
    /// rellenas menos Estadísticas, y esa mezcla de pesos era lo que
    /// recargaba la barra. Así solo hay un glifo sólido a la vez y la
    /// selección se lee por forma, no solo por color.
    private func icono(de pestania: RootTabView.Pestania) -> String {
        let base = switch pestania {
        case .inicio: "house"
        case .movimientos: "list.bullet.rectangle"
        // `chart.bar` y no `chart.bar.xaxis`: este último no tiene variante
        // rellena (lo confirma el mapeo del sistema), así que al
        // seleccionarlo el símbolo no existiría. Es el mismo gráfico de
        // barras, sin la línea del eje.
        case .estadisticas: "chart.bar"
        case .configuracion: "gearshape"
        }
        return pestania == seleccion ? "\(base).fill" : base
    }

    /// Copia del ícono activo por encima del vidrio. Sin esto, la burbuja
    /// difumina lo que tapa y el ícono de adentro queda ilegible.
    @ViewBuilder
    private var iconoActivoNitido: some View {
        if let marco = marcos[seleccion] {
            Image(systemName: icono(de: seleccion))
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .position(x: marco.midX, y: alturaBarra / 2)
                .allowsHitTesting(false)
                // Sin animación de posición a propósito: con el spring, al
                // arrastrar el ícono activo se deslizaba de una pestaña a
                // la otra. Así aparece quieto en la que corresponde y la
                // única que se mueve es la burbuja.
                .animation(nil, value: seleccion)
        }
    }

    private func item(
        _ pestania: RootTabView.Pestania,
        _ titulo: String
    ) -> some View {
        // Sin Button: el toque lo resuelve el gesto de la barra, que es el
        // mismo que permite arrastrar la píldora.
        // Solo el ícono: el nombre sigue estando como etiqueta de
        // accesibilidad, así VoiceOver no pierde nada.
        // El activo se oculta acá porque se redibuja nítido sobre la
        // burbuja; si no, se vería dos veces.
        Image(systemName: icono(de: pestania))
            .font(.system(size: 23, weight: .medium))
            .foregroundStyle(seleccion == pestania ? Color.clear : Color.secondary)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titulo)
        .accessibilityAddTraits(seleccion == pestania ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            if pestania == .inicio && seleccion == .inicio { alTocarInicio() }
            seleccion = pestania
        }
        // Publica su posición para que la píldora sepa dónde pararse.
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: MarcosPestanias.self,
                    value: [pestania: proxy.frame(in: .named(Self.espacioBarra))]
                )
            }
        )
    }
}

/// Junta los marcos de las pestañas para posicionar la píldora.
private struct MarcosPestanias: PreferenceKey {
    static let defaultValue: [RootTabView.Pestania: CGRect] = [:]

    static func reduce(
        value: inout [RootTabView.Pestania: CGRect],
        nextValue: () -> [RootTabView.Pestania: CGRect]
    ) {
        value.merge(nextValue()) { _, nuevo in nuevo }
    }
}

/// Liquid Glass nativo en iOS 26+ con la forma recortada; en versiones
/// anteriores, material translúcido con la misma silueta.
private struct FondoBarraConMuesca: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // `.clear` y no `.regular`: la regular difumina fuerte y dejaba
            // la barra opaca. La clara casi no difumina y se ve el
            // contenido pasar por detrás.
            content.glassEffect(.clear, in: BarraConMuesca())
        } else {
            content
                .background(.ultraThinMaterial, in: BarraConMuesca())
                .overlay {
                    BarraConMuesca()
                        .stroke(.white.opacity(0.05), lineWidth: 0.5)
                }
        }
    }
}

/// Vidrio de la píldora de selección. Va en `.clear` y no en `.regular`:
/// la variante clara casi no difumina, así que se comporta como una lente
/// que deja ver el contenido de atrás, en vez de una mancha esmerilada.
/// Sin `interactive` a propósito: ese modificador la agranda al tocarla y
/// la hacía desbordar la barra.
private struct VidrioPildora<Forma: Shape>: ViewModifier {
    let forma: Forma

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.clear, in: forma)
        } else {
            content.background(.primary.opacity(0.2), in: forma)
        }
    }
}

