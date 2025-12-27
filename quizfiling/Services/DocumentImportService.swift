import Foundation
import UIKit
import SwiftData

struct ImportedDocumentPayload {
    let title: String
    let filePaths: [String]
    let pageCount: Int
}

@MainActor
final class DocumentImportService {
    private let storage = FileStorageService.shared

    func importPDF(from url: URL) throws -> ImportedDocumentPayload {
        let stored = try storage.storeFile(from: url)
        return ImportedDocumentPayload(title: url.deletingPathExtension().lastPathComponent, filePaths: [stored], pageCount: 0)
    }

    func importImages(urls: [URL]) throws -> ImportedDocumentPayload {
        var paths: [String] = []
        for (index, url) in urls.enumerated() {
            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data) else { continue }
            let path = try storage.storeImage(image, index: index)
            paths.append(path)
        }
        return ImportedDocumentPayload(title: "画像インポート", filePaths: paths, pageCount: paths.count)
    }

    func importScan(pdfData: Data, images: [UIImage]) throws -> ImportedDocumentPayload {
        if !pdfData.isEmpty {
            let path = try storage.storePDF(data: pdfData)
            return ImportedDocumentPayload(title: "スキャン", filePaths: [path], pageCount: images.count)
        }
        var paths: [String] = []
        for (index, image) in images.enumerated() {
            let path = try storage.storeImage(image, index: index)
            paths.append(path)
        }
        return ImportedDocumentPayload(title: "スキャン", filePaths: paths, pageCount: images.count)
    }
}
