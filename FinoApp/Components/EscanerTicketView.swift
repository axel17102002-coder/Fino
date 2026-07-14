import SwiftUI
import VisionKit

/// Cámara de escaneo de documentos del sistema (la misma de Notas):
/// detecta el borde del ticket, lo endereza y devuelve la imagen lista
/// para el OCR.
struct EscanerTicketView: UIViewControllerRepresentable {

    /// Recibe la imagen escaneada, o `nil` si se canceló.
    let alTerminar: (UIImage?) -> Void

    static var disponible: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camara = VNDocumentCameraViewController()
        camara.delegate = context.coordinator
        return camara
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinador {
        Coordinador(alTerminar: alTerminar)
    }

    final class Coordinador: NSObject, VNDocumentCameraViewControllerDelegate {
        let alTerminar: (UIImage?) -> Void

        init(alTerminar: @escaping (UIImage?) -> Void) {
            self.alTerminar = alTerminar
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            alTerminar(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            alTerminar(nil)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            alTerminar(nil)
        }
    }
}
