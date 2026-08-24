import SwiftUI
import WidgetKit

/// Complicaciones de Fino para la esfera del Apple Watch.
@main
struct FinoWatchWidgetBundle: WidgetBundle {

    var body: some Widget {
        AgregarGastoComplicacion()
        GastosDelMesComplicacion()
    }
}
