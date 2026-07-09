import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let store: NoteStore
    private let settings: AppSettings
    private var panel: FloatingNotePanel?
    private var localKeyMonitor: Any?

    init(store: NoteStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        placePanel(panel)
        installLocalKeyMonitor()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        store.flushPendingSave()
        panel?.orderOut(nil)
        removeLocalKeyMonitor()
    }

    func applyPlacement() {
        guard let panel else {
            return
        }

        placePanel(panel)
    }

    func applyPlacement(sidebarCollapsed: Bool) {
        guard let panel else {
            return
        }

        placePanel(panel, sidebarCollapsed: sidebarCollapsed)
    }

    private func makePanel() -> FloatingNotePanel {
        let panel = FloatingNotePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 640),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.title = "MinNote"
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = false
        panel.level = .normal
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.managed, .fullScreenPrimary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 180, height: 320)
        panel.delegate = self
        panel.onCancel = { [weak self] in
            self?.hide()
        }

        let rootView = ContentView(
            store: store,
            settings: settings,
            onSidebarChange: { [weak self] sidebarCollapsed in
                self?.applyPlacement(sidebarCollapsed: sidebarCollapsed)
            },
            onOpenStorageLocation: { [weak self] in
                guard let self else {
                    return
                }

                let directory = self.store.storageDirectory
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                NSWorkspace.shared.open(directory)
            }
        )
        let hostingController = FullSizeHostingController(rootView: rootView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 18
        hostingController.view.layer?.masksToBounds = true
        panel.contentViewController = hostingController

        return panel
    }

    private func placePanel(_ panel: NSPanel, sidebarCollapsed: Bool? = nil) {
        guard let screen = screen(for: panel) else {
            panel.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let frame = panelFrame(
            for: settings.attachment,
            in: visibleFrame,
            sidebarCollapsed: sidebarCollapsed
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            panel.disableScreenUpdatesUntilFlush()
            panel.setFrame(frame, display: true, animate: false)
        }
    }

    private func panelFrame(
        for attachment: PanelAttachment,
        in visibleFrame: NSRect,
        sidebarCollapsed: Bool? = nil
    ) -> NSRect {
        switch attachment {
        case .left:
            let width = sidePanelWidth(in: visibleFrame, sidebarCollapsed: sidebarCollapsed)
            return NSRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: width,
                height: visibleFrame.height
            )
        case .right:
            let width = sidePanelWidth(in: visibleFrame, sidebarCollapsed: sidebarCollapsed)
            return NSRect(
                x: visibleFrame.maxX - width,
                y: visibleFrame.minY,
                width: width,
                height: visibleFrame.height
            )
        case .bottom:
            let width = min(720, visibleFrame.width * 0.62)
            let height = min(420, visibleFrame.height * 0.46)
            return NSRect(
                x: visibleFrame.midX - width / 2,
                y: visibleFrame.minY,
                width: width,
                height: height
            )
        }
    }

    private func screen(for panel: NSPanel) -> NSScreen? {
        if let screen = panel.screen {
            return screen
        }

        let frame = panel.frame
        return NSScreen.screens.max { lhs, rhs in
            lhs.visibleFrame.intersection(frame).area < rhs.visibleFrame.intersection(frame).area
        } ?? NSScreen.main
    }

    private func sidePanelWidth(in visibleFrame: NSRect, sidebarCollapsed: Bool?) -> CGFloat {
        let collapsed = sidebarCollapsed ?? UserDefaults.standard.bool(forKey: "sidebarCollapsed")
        let collapsedWidth = min(420, floor(visibleFrame.width / 4))

        guard !collapsed else {
            return collapsedWidth
        }

        return min(visibleFrame.width * 0.55, max(520, collapsedWidth + 210))
    }

    private func installLocalKeyMonitor() {
        guard localKeyMonitor == nil else {
            return
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            guard event.window === self.panel else {
                return event
            }

            if event.keyCode == 53 {
                self.hide()
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if modifiers.contains(.command), event.charactersIgnoringModifiers == "n" {
                self.store.createNote()
                return nil
            }

            if self.settings.markdownPreviewHotKey.matches(event: event) {
                NotificationCenter.default.post(name: .toggleMarkdownPreview, object: nil)
                return nil
            }

            if self.settings.markdownToolbarHotKey.matches(event: event) {
                NotificationCenter.default.post(name: .toggleMarkdownToolbar, object: nil)
                return nil
            }

            if self.settings.markdownToolbarTopHotKey.matches(event: event) {
                self.settings.markdownToolbarPosition = .top
                return nil
            }

            if self.settings.markdownToolbarBottomHotKey.matches(event: event) {
                self.settings.markdownToolbarPosition = .bottom
                return nil
            }

            if let markdownAction = self.markdownFormattingAction(matching: event) {
                NotificationCenter.default.post(
                    name: .applyMarkdownFormatting,
                    object: markdownAction.rawValue
                )
                return nil
            }

            if self.settings.sidebarHotKey.matches(event: event) {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                return nil
            }

            if self.settings.sidebarModeHotKey.matches(event: event) {
                NotificationCenter.default.post(name: .toggleSidebarMode, object: nil)
                return nil
            }

            if self.settings.previousNoteHotKey.matches(event: event) {
                self.store.selectPrevious()
                return nil
            }

            if self.settings.nextNoteHotKey.matches(event: event) {
                self.store.selectNext()
                return nil
            }

            if self.settings.deleteNoteHotKey.matches(event: event) {
                self.store.deleteSelectedNote()
                return nil
            }

            if modifiers.contains(.command), event.charactersIgnoringModifiers == "w" {
                return event
            }

            return event
        }
    }

    private func markdownFormattingAction(matching event: NSEvent) -> MarkdownFormattingAction? {
        MarkdownFormattingAction.allCases.first { action in
            settings.markdownFormattingHotKey(for: action).matches(event: event)
        }
    }

    private func removeLocalKeyMonitor() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        store.flushPendingSave()
        removeLocalKeyMonitor()
    }

}

private final class FullSizeHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        view = FullSizeHostingView(rootView: rootView)
    }
}

private final class FullSizeHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    override var safeAreaRect: NSRect {
        bounds
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull else {
            return 0
        }

        return width * height
    }
}
