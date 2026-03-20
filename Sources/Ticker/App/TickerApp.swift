import SwiftUI
import TickerKit

@main
@MainActor
struct TickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: TickerStore

    init() {
        let store = TickerStore()
        _store = StateObject(wrappedValue: store)
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
