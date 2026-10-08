import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                CatchItMenuBarMark().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome to Catch It").font(.title2.weight(.semibold))
                    Text(page == 0 ? LocalizedStringKey("Give Catch It permission to read selected screen areas.") : LocalizedStringKey("Your captures stay on this Mac."))
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            if page == 0 {
                Label("Screen Recording", systemImage: "rectangle.dashed.badge.record")
                    .font(.headline)
                Text("macOS asks for Screen Recording access the first time you capture. Catch It uses ScreenCaptureKit to read only the area you select, then sends the image to Apple Vision on this Mac.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("If macOS does not show the permission prompt, use the button below to open Privacy & Security settings. Quit and reopen Catch It after changing access.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Screen Recording Settings…") { model.openScreenRecordingSettings() }
                    .accessibilityHint("Opens macOS Privacy & Security settings")
            } else {
                Label("Local by design", systemImage: "lock.shield")
                    .font(.headline)
                Text("Recognized text is copied to your clipboard. Captured images are processed in memory and discarded. Catch It makes no network requests and collects no analytics.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Start a capture from the menu bar or use Control–Option–Space. Press Escape to cancel a selection.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack {
                Text(AppText.formatted("Page %lld of 2", page + 1)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if page > 0 {
                    Button("Back") { page = 0 }
                }
                Button(page == 0 ? "Continue" : "Get Started") {
                    if page == 0 { page = 1 } else { model.finishOnboarding() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
