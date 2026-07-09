import AppKit
import Foundation

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    let settings = AppSettings()
    lazy var store = NoteStore(settings: settings)

    private lazy var panelController = FloatingPanelController(store: store, settings: settings)
    private var hotKeyManager: HotKeyManager?
    private var didStart = false

    private init() {}

    func start() {
        guard !didStart else {
            return
        }

        didStart = true
        NSApp.setActivationPolicy(.regular)

        let hotKeyManager = HotKeyManager { [weak self] in
            self?.togglePanel()
        }

        self.hotKeyManager = hotKeyManager
        registerHotKey()
        updateAppearance()
        syncLaunchAtLoginStatus()

        panelController.show()
    }

    func stop() {
        store.flushPendingSave()
        hotKeyManager?.unregister()
        hotKeyManager = nil
    }

    func togglePanel() {
        panelController.toggle()
    }

    func showPanel() {
        panelController.show()
    }

    func hidePanel() {
        panelController.hide()
    }

    func createNoteAndShow() {
        store.createNote()
        panelController.show()
    }

    func deleteSelectedNote() {
        store.deleteSelectedNote()
    }

    func updateHotKey() {
        registerHotKey()
    }

    func updatePanelPlacement() {
        panelController.applyPlacement()
    }

    func updateStorageLocation() {
        store.reloadFromStorage()
    }

    func updateNoteFormat() {
        // Format changes only affect new notes and the next edit of the selected note.
    }

    func updateAppearance() {
        NSApp.appearance = settings.appearance.nsAppearance
    }

    func updateLaunchAtLogin() {
        do {
            try LaunchAtLoginManager.setEnabled(settings.launchAtLoginEnabled)
            syncLaunchAtLoginStatus()
        } catch {
            NSLog("MinNote launch at login update failed: \(error.localizedDescription)")
            syncLaunchAtLoginStatus()
        }
    }

    func openStorageLocation() {
        let directory = store.storageDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    private func registerHotKey() {
        do {
            try hotKeyManager?.register(configuration: settings.hotKey)
        } catch {
            NSLog("MinNote hot key unavailable: \(error.localizedDescription)")
        }
    }

    private func syncLaunchAtLoginStatus() {
        let isEnabled = LaunchAtLoginManager.isEnabled

        if settings.launchAtLoginEnabled != isEnabled {
            settings.launchAtLoginEnabled = isEnabled
        }
    }
}
