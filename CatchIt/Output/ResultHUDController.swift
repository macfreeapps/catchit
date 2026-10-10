import AppKit

struct HUDAction {
    let title: String
    let handler: () -> Void
}

@MainActor
final class ResultHUDController: NSObject {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var actionHandlers: [Int: () -> Void] = [:]

    func show(message: String, near selection: CGRect, enabled: Bool, actions: [HUDAction] = []) {
        dismiss()
        guard enabled else { return }

        let label = NSTextField(wrappingLabelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.maximumNumberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 9
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        stack.addArrangedSubview(label)
        actionHandlers.removeAll()
        if !actions.isEmpty {
            let buttons = NSStackView()
            buttons.orientation = .horizontal
            buttons.alignment = .centerY
            buttons.spacing = 7
            for (index, action) in actions.enumerated() {
                let button = NSButton(title: action.title, target: self, action: #selector(performAction(_:)))
                button.tag = index
                button.bezelStyle = .rounded
                button.controlSize = .small
                button.setAccessibilityLabel(action.title)
                buttons.addArrangedSubview(button)
                actionHandlers[index] = action.handler
            }
            stack.addArrangedSubview(buttons)
        }
        stack.wantsLayer = true
        stack.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.97).cgColor
        stack.layer?.cornerRadius = 11

        let width: CGFloat = actions.isEmpty ? 240 : 300
        // Measure wrapped text so translated messages do not collide with actions.
        let textWidth = width - 28
        label.preferredMaxLayoutWidth = textWidth
        let textHeight = ceil((message as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: label.font ?? NSFont.systemFont(ofSize: 13)]
        ).height)
        let lineHeight = ceil((label.font ?? NSFont.systemFont(ofSize: 13)).boundingRectForFont.height)
        let height = max(22, min(textHeight, lineHeight * 3)) + 24 + (actions.isEmpty ? 0 : 31)
        let hud = NSPanel(contentRect: CGRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        hud.isOpaque = false
        hud.backgroundColor = .clear
        hud.hasShadow = true
        hud.level = .floating
        hud.ignoresMouseEvents = actions.isEmpty
        hud.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        stack.frame = CGRect(x: 0, y: 0, width: width, height: height)
        stack.autoresizingMask = [.width, .height]
        hud.contentView = stack

        let screen = NSScreen.screens.first(where: { $0.frame.intersects(selection) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1024, height: 768)
        let x = min(selection.maxX + 12, visibleFrame.maxX - hud.frame.width)
        let y = min(max(selection.minY, visibleFrame.minY + 12), visibleFrame.maxY - hud.frame.height)
        hud.setFrameOrigin(CGPoint(x: max(visibleFrame.minX + 12, x), y: y))
        hud.orderFrontRegardless()
        panel = hud

        dismissTask = Task { [weak self, weak hud] in
            try? await Task.sleep(for: .seconds(actions.isEmpty ? 1.6 : 5.0))
            guard !Task.isCancelled else { return }
            guard let self, let hud, self.panel === hud else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                hud.animator().alphaValue = 0
            } completionHandler: { [weak self, weak hud] in
                guard let self, let hud, self.panel === hud else { return }
                self.dismiss()
            }
        }
    }

    @objc private func performAction(_ sender: NSButton) {
        let action = actionHandlers[sender.tag]
        dismiss()
        action?()
    }

    private func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
        panel = nil
        actionHandlers.removeAll()
    }
}
