import AppKit
import TickerKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = TickerStore()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.start()

        let statusBarController = StatusBarController(store: store)
        statusBarController.install()
        self.statusBarController = statusBarController
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.tearDown()
    }
}
