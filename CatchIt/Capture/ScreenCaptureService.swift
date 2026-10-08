import AppKit
import ScreenCaptureKit
import os

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case displayUnavailable
    case invalidSelection

    var errorDescription: String? {
        switch self {
        case .permissionDenied: AppText.localized("Screen Recording permission is required.")
        case .displayUnavailable: AppText.localized("The selected display is no longer available.")
        case .invalidSelection: AppText.localized("The selected area is too small to capture.")
        }
    }
}

@MainActor
final class ScreenCaptureService {
    private let logger = Logger(subsystem: "com.tarudesu.CatchIt", category: "ScreenCapture")

    func capture(_ selection: CaptureSelection) async throws -> CGImage {
        guard selection.globalRect.width >= 3, selection.globalRect.height >= 3 else {
            throw ScreenCaptureError.invalidSelection
        }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionDenied
        }

        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == selection.displayID }) else {
                throw ScreenCaptureError.displayUnavailable
            }

            let ownPID = ProcessInfo.processInfo.processIdentifier
            let ownApplication = content.applications.first(where: { $0.processID == ownPID })
            let filter: SCContentFilter
            if let ownApplication {
                filter = SCContentFilter(display: display, excludingApplications: [ownApplication], exceptingWindows: [])
            } else {
                let ownWindows = content.windows.filter { $0.owningApplication?.processID == ownPID }
                filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            }

            let localRect = selection.globalRect.offsetBy(dx: -selection.screenFrame.minX, dy: -selection.screenFrame.minY)
            let captureRect = CGRect(
                x: localRect.minX,
                y: CGFloat(display.height) - localRect.maxY,
                width: localRect.width,
                height: localRect.height
            )
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = captureRect
            configuration.width = max(1, Int((captureRect.width * CGFloat(filter.pointPixelScale)).rounded()))
            configuration.height = max(1, Int((captureRect.height * CGFloat(filter.pointPixelScale)).rounded()))
            configuration.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            if isPermissionError(error) {
                throw ScreenCaptureError.permissionDenied
            }
            logger.error("ScreenCaptureKit error: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func isPermissionError(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("permission") || description.contains("not authorized") || description.contains("denied")
    }
}
