import AppKit
import Carbon
import Foundation
import os

enum HotKeyAction: String, CaseIterable, Codable, Hashable, Sendable {
    case catchText
    case catchBarcode
    case catchSameArea
    case toggleAdditive
    case clearCollection
    case captureAndSpeak
    case stopSpeaking

    var title: String {
        AppText.localized(titleKey)
    }

    private var titleKey: String {
        switch self {
        case .catchText: "Catch Text"
        case .catchBarcode: "Catch Barcode"
        case .catchSameArea: "Catch Same Area"
        case .toggleAdditive: "Toggle Additive Mode"
        case .clearCollection: "Clear Collection"
        case .captureAndSpeak: "Capture and Speak"
        case .stopSpeaking: "Stop Speaking"
        }
    }
}

struct HotKeyBinding: Codable, Hashable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    var displayName: String {
        var prefix = ""
        if modifiers & UInt32(controlKey) != 0 { prefix += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { prefix += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { prefix += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { prefix += "⌘" }
        return prefix + Self.keyName(keyCode)
    }

    static let defaults: [HotKeyAction: HotKeyBinding] = [
        .catchText: HotKeyBinding(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey)),
        .catchBarcode: HotKeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(controlKey | optionKey)),
        .catchSameArea: HotKeyBinding(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(controlKey | optionKey)),
        .toggleAdditive: HotKeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey)),
        .clearCollection: HotKeyBinding(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey)),
        .captureAndSpeak: HotKeyBinding(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey | shiftKey)),
        .stopSpeaking: HotKeyBinding(keyCode: UInt32(kVK_Escape), modifiers: UInt32(controlKey | optionKey))
    ]

    static func from(event: NSEvent) -> HotKeyBinding? {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !flags.isEmpty else { return nil }
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return HotKeyBinding(keyCode: UInt32(event.keyCode), modifiers: carbon)
    }

    private static func keyName(_ code: UInt32) -> String {
        let names: [UInt32: String] = [UInt32(kVK_Space): AppText.localized("Space key"), UInt32(kVK_Escape): "Esc", UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥", UInt32(kVK_Delete): "⌫"]
        if let name = names[code] { return name }
        let keyMap: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
            UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F", UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
            UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
            UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R", UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
            UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z", UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1",
            UInt32(kVK_ANSI_2): "2", UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8", UInt32(kVK_ANSI_9): "9"
        ]
        return keyMap[code] ?? AppText.formatted("Key %lld", Int(code))
    }
}

@MainActor
final class GlobalHotKey: @unchecked Sendable {
    var onPress: ((HotKeyAction) -> Void)?
    private let logger = Logger(subsystem: "com.tarudesu.CatchIt", category: "HotKey")
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    func register(_ bindings: [HotKeyAction: HotKeyBinding]) {
        unregister()
        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(
                GetApplicationEventTarget(), catchItHotKeyEventHandler, 1, &eventType,
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandlerRef
            )
            guard status == noErr else {
                logger.error("Could not install shortcut handler (\(status))")
                return
            }
        }

        var claimed = Set<String>()
        for action in HotKeyAction.allCases {
            guard let binding = bindings[action] else { continue }
            let identity = "\(binding.keyCode):\(binding.modifiers)"
            guard claimed.insert(identity).inserted else {
                logger.error("Duplicate shortcut for \(action.rawValue, privacy: .public)")
                continue
            }
            let identifier = EventHotKeyID(signature: OSType(0x43415443), id: UInt32(actionIndex(action) + 1))
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, identifier, GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference {
                hotKeyRefs.append(reference)
            } else {
                logger.error("Could not register shortcut for \(action.rawValue, privacy: .public) (\(status))")
            }
        }
    }

    func unregister() {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
    }

    private func actionIndex(_ action: HotKeyAction) -> Int { HotKeyAction.allCases.firstIndex(of: action) ?? 0 }

    fileprivate func handlePress(id: UInt32) {
        guard let rawIndex = Int(exactly: id), rawIndex > 0 else { return }
        let index = rawIndex - 1
        guard HotKeyAction.allCases.indices.contains(index) else { return }
        onPress?(HotKeyAction.allCases[index])
    }
}

private let catchItHotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var pressedID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &pressedID)
    guard status == noErr else { return status }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in hotKey.handlePress(id: pressedID.id) }
    return noErr
}
