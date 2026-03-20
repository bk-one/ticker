import SwiftUI
import TickerKit

@main
@MainActor
struct TickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let store = TickerStore()

    init() {
        store.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: store)
        } label: {
            MenuBarLabel(model: store)
        }
        .menuBarExtraStyle(.window)
    }
}
