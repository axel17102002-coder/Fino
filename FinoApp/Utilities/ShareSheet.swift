import SwiftUI
import UIKit

/// Envoltorio de `UIActivityViewController` para compartir archivos.
struct ShareSheet: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Identifica un archivo generado para presentarlo con `.sheet(item:)`.
struct ArchivoExportado: Identifiable {
    let url: URL
    var id: String { url.path }
}
