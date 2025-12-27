import Foundation
import UIKit

struct FileStorageService {
    static let shared = FileStorageService()

    private let baseURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.baseURL = documents.appendingPathComponent("Imported", isDirectory: true)
        createBaseDirectoryIfNeeded()
    }

    private func createBaseDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: baseURL.path) {
            try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }

    func storeFile(from url: URL) throws -> String {
        let targetName = UUID().uuidString + "-" + url.lastPathComponent
        let targetURL = baseURL.appendingPathComponent(targetName)
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: url, to: targetURL)
        return targetName
    }

    func storePDF(data: Data) throws -> String {
        let fileName = UUID().uuidString + ".pdf"
        let url = baseURL.appendingPathComponent(fileName)
        try data.write(to: url)
        return fileName
    }

    func storeImage(_ image: UIImage, index: Int) throws -> String {
        let fileName = UUID().uuidString + "-page-\(index).jpg"
        let url = baseURL.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url)
        return fileName
    }

    func resolve(_ path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    func remove(_ path: String) {
        let url = resolve(path)
        try? FileManager.default.removeItem(at: url)
    }

    func purgeAll() throws {
        if FileManager.default.fileExists(atPath: baseURL.path) {
            try FileManager.default.removeItem(at: baseURL)
        }
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
}
