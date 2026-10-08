import Foundation
import Vision

struct BarcodeRecognizer {
    func recognize(in image: CGImage) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            try VNImageRequestHandler(cgImage: image).perform([request])
            var seen = Set<String>()
            return (request.results ?? []).compactMap { $0.payloadStringValue }.filter { seen.insert($0).inserted }
        }.value
    }
}
