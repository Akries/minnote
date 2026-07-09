import AppKit
import SwiftUI

@main
struct MinNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let controller = AppController.shared

    var body: some Scene {
        MenuBarExtra("MinNote", systemImage: "note.text") {
            Button("显示/隐藏") {
                controller.togglePanel()
            }

            Button("新建笔记") {
                controller.createNoteAndShow()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("删除当前笔记") {
                controller.deleteSelectedNote()
            }

            Button("打开存储位置") {
                controller.openStorageLocation()
            }

            Divider()

            SettingsLink {
                Label("设置", systemImage: "gearshape")
            }

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(settings: controller.settings) {
                controller.updateHotKey()
            } onAttachmentChange: {
                controller.updatePanelPlacement()
            } onStorageChange: {
                controller.updateStorageLocation()
            } onOpenStorageLocation: {
                controller.openStorageLocation()
            } onFormatChange: {
                controller.updateNoteFormat()
            } onAppearanceChange: {
                controller.updateAppearance()
            } onLaunchAtLoginChange: {
                controller.updateLaunchAtLogin()
            }
        }
    }
}
