import SwiftUI
import VisionKit

struct DocumentScanResult {
    let pdfData: Data
    let images: [UIImage]
}

struct DocumentScannerView: UIViewControllerRepresentable {
    let onComplete: (DocumentScanResult) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: (DocumentScanResult) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping (DocumentScanResult) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            let pdfData = makePDFData(from: images)
            controller.dismiss(animated: true)
            onComplete(DocumentScanResult(pdfData: pdfData, images: images))
        }

        private func makePDFData(from images: [UIImage]) -> Data {
            let renderer = UIGraphicsPDFRenderer(bounds: .zero)
            return renderer.pdfData { context in
                for image in images {
                    let bounds = CGRect(origin: .zero, size: image.size)
                    context.beginPage(withBounds: bounds, pageInfo: [:])
                    image.draw(in: bounds)
                }
            }
        }
    }
}
