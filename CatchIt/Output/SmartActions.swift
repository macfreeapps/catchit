import AppKit
import Foundation

struct SmartAction: Identifiable, Equatable {
    enum Kind: String { case url, email, phone }
    let kind: Kind
    let value: String
    var id: String { "\(kind.rawValue):\(value)" }
}

enum SmartActionDetector {
    static func detect(in text: String) -> [SmartAction] {
        let checkingTypes = NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        guard let detector = try? NSDataDetector(types: checkingTypes) else { return [] }
        var seen = Set<String>()
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let raw = String(text[range])
            if let phone = match.phoneNumber {
                guard seen.insert("phone:\(phone)").inserted else { return nil }
                return SmartAction(kind: .phone, value: phone)
            }
            guard let url = match.url else { return nil }
            let kind: SmartAction.Kind
            switch url.scheme?.lowercased() {
            case "mailto": kind = .email
            case "tel": kind = .phone
            default: kind = .url
            }
            guard seen.insert(url.absoluteString).inserted else { return nil }
            return SmartAction(kind: kind, value: kind == .url ? url.absoluteString : raw)
        }
    }

    static func open(_ action: SmartAction) {
        let value = action.kind == .url ? action.value : "\(action.kind == .email ? "mailto" : "tel"):\(action.value)"
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}
