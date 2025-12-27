import Foundation
import PDFKit
import UIKit

struct PDFRenderService {
    func renderPages(url: URL) throws -> [CGImage] {
        guard let document = PDFDocument(url: url) else { return [] }
        var images: [CGImage] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(pageRect)
                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: context.cgContext)
            }
            if let cgImage = image.cgImage {
                images.append(cgImage)
            }
        }
        return images
    }
}
