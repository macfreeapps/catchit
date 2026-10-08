import AppKit
import PDFKit
import UniformTypeIdentifiers

enum FileRecognitionError: LocalizedError {
    case unsupportedFile
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: AppText.localized("Choose an image or PDF file.")
        case .unreadableImage: AppText.localized("Catch It could not read this file.")
        }
    }
}

struct FileRecognitionService {
    func images(from url: URL) throws -> [CGImage] {
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { throw FileRecognitionError.unreadableImage }
            let pages = (0..<document.pageCount).compactMap { index -> CGImage? in
                guard let page = document.page(at: index) else { return nil }
                let bounds = page.bounds(for: .mediaBox)
                let size = CGSize(width: max(1, bounds.width * 2), height: max(1, bounds.height * 2))
                let thumbnail = page.thumbnail(of: size, for: .mediaBox)
                return thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
            guard !pages.isEmpty else { throw FileRecognitionError.unreadableImage }
            return pages
        }

        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw FileRecognitionError.unsupportedFile
        }
        return [cgImage]
    }
}
