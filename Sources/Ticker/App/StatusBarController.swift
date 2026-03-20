import AppKit
import Combine
import SwiftUI
import TickerKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: TickerStore
    private let popover = NSPopover()
    private let searchPanelController: InstrumentSearchPanelController
    private var cancellables = Set<AnyCancellable>()

    init(
        store: TickerStore,
        searchClient: YahooFinanceSearchClientProtocol = YahooFinanceSearchClient()
    ) {
        self.store = store
        self.searchPanelController = InstrumentSearchPanelController(store: store, searchClient: searchClient)
        super.init()

        configureStatusItem()
        configurePopover()
        observeStore()
    }

    func install() {
        updateStatusButton()
    }

    func tearDown() {
        popover.performClose(nil)
        searchPanelController.close()
        statusItem.button?.target = nil
        statusItem.button?.action = nil
        cancellables.removeAll()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 356, height: 320)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(
                model: store,
                onAddInstrument: { [weak self] in
                    guard let self else {
                        return
                    }

                    self.popover.performClose(nil)

                    if let button = self.statusItem.button {
                        self.toggleSearchPanel(relativeTo: button)
                    }
                }
            )
        )
    }

    private func observeStore() {
        store.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusButton()
                    self?.updatePopoverSize()
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        button.image = MenuBarLabelRenderer.image(for: store)
        button.setAccessibilityTitle(MenuBarLabelRenderer.accessibilityLabel(for: store))
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            toggleSearchPanel(relativeTo: sender)
            return
        }

        if isSecondaryClick(event) {
            searchPanelController.close()
            togglePopover(relativeTo: sender)
        } else {
            popover.performClose(nil)
            toggleSearchPanel(relativeTo: sender)
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        updatePopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func toggleSearchPanel(relativeTo button: NSStatusBarButton) {
        searchPanelController.toggle(relativeTo: button)
    }

    private func isSecondaryClick(_ event: NSEvent) -> Bool {
        event.type == .rightMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
    }

    private func updatePopoverSize() {
        guard let contentView = popover.contentViewController?.view else {
            return
        }

        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        popover.contentSize = NSSize(
            width: max(320, fittingSize.width),
            height: max(1, fittingSize.height)
        )
    }
}
