import SwiftUI
import TickerKit

@main
@MainActor
struct TickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TickerStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: store)
        } label: {
            MenuBarLabel(model: store)
                .task {
                    store.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
