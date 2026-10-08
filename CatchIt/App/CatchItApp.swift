import SwiftUI

@main
struct CatchItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Settings {
            SettingsView(model: model)
                .frame(width: 680, height: 520)
        }
    }
}
