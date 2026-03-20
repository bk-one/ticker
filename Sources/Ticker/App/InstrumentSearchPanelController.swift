import AppKit
import SwiftUI
import TickerKit

@MainActor
final class InstrumentSearchPanelController: NSObject, NSWindowDelegate {
    private let store: TickerStore
    private let searchClient: YahooFinanceSearchClientProtocol
    private lazy var viewModel = InstrumentSearchViewModel(
        store: store,
        searchClient: searchClient
    )
    private lazy var panel: InstrumentSearchPanel = {
        let panel = InstrumentSearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 548, height: 468),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = true
        panel.delegate = self
        panel.onCancel = { [weak self] in
            self?.close()
        }
        panel.contentViewController = NSHostingController(
            rootView: InstrumentSearchPanelView(
                model: viewModel,
                onDismiss: { [weak self] in
                    self?.close()
                }
            )
        )
        return panel
    }()
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(
        store: TickerStore,
        searchClient: YahooFinanceSearchClientProtocol
    ) {
        self.store = store
        self.searchClient = searchClient
        super.init()
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if panel.isVisible {
            close()
        } else {
            show(on: button.window?.screen)
        }
    }

    func close() {
        guard panel.isVisible else {
            viewModel.endSession()
            return
        }

        removeOutsideClickMonitors()
        panel.orderOut(nil)
        viewModel.endSession()
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func show(on screen: NSScreen?) {
        let targetScreen = screen ?? NSScreen.main
        positionPanel(on: targetScreen)
        installOutsideClickMonitors()
        viewModel.beginSession()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func positionPanel(on screen: NSScreen?) {
        let targetFrame = (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: targetFrame.midX - (panel.frame.width / 2),
            y: targetFrame.midY - (panel.frame.height / 2)
        )
        panel.setFrameOrigin(origin)
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self,
                  self.panel.isVisible else {
                return event
            }

            if event.window !== self.panel,
               !self.panel.frame.contains(NSEvent.mouseLocation) {
                self.close()
            }

            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func removeOutsideClickMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }
}

private final class InstrumentSearchPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
