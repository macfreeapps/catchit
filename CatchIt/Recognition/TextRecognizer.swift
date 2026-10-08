import Foundation
import CoreImage
import Vision

struct OCRPreferences: Sendable {
    let primaryLanguage: String
    let automaticallyDetectsLanguage: Bool
    let codeSymbolsMode: Bool
    let customWords: [String]
    let keepLineBreaks: Bool
}

struct TextRecognizer {
    func recognize(in image: CGImage, preferences: OCRPreferences) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let preparedImage = Self.upscaledIfSmall(image)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = !preferences.codeSymbolsMode
            request.customWords = preferences.customWords
            if !preferences.automaticallyDetectsLanguage {
                let supported = (try? request.supportedRecognitionLanguages()) ?? []
                let primary = supported.contains(preferences.primaryLanguage) ? preferences.primaryLanguage : supported.first ?? "en-US"
                request.recognitionLanguages = [primary]
            }
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = preferences.automaticallyDetectsLanguage
            }

            try VNImageRequestHandler(cgImage: preparedImage).perform([request])
            let lines = (request.results ?? []).compactMap { observation in
                observation.topCandidates(1).first.map {
                    RecognizedLine(text: $0.string, bounds: observation.boundingBox)
                }
            }
            return TextPostProcessor.format(lines, keepLineBreaks: preferences.keepLineBreaks)
        }.value
    }

    static func supportedLanguages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return (try? request.supportedRecognitionLanguages()) ?? [Locale.preferredLanguages.first ?? "en-US"]
    }

    private static func upscaledIfSmall(_ image: CGImage) -> CGImage {
        guard image.width < 180 || image.height < 100 else { return image }
        let source = CIImage(cgImage: image)
        let scaled = source.transformed(by: CGAffineTransform(scaleX: 2, y: 2))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(scaled, from: scaled.extent) ?? image
    }
}
