import SwiftUI
import WidgetKit

@main
struct AtharApp: App {
    @StateObject private var store = AtharStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .tint(Theme.accent)
                .preferredColorScheme(nil)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Prayer alerts are only scheduled a week out; top them up on every launch.
                Task { await Reminders.rescheduleAthan(store: store) }
            case .background:
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }
}
