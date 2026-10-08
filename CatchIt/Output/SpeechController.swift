import AVFoundation
import Foundation

@MainActor
final class SpeechController {
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool { synthesizer.isSpeaking }

    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func speak(_ text: String, voiceIdentifier: String, rate: Double) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        if !voiceIdentifier.isEmpty {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        }
        let normalized = min(max(rate, 0), 1)
        utterance.rate = AVSpeechUtteranceMinimumSpeechRate + Float(normalized) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
