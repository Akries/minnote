import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let onHotKeyChange: () -> Void
    let onAttachmentChange: () -> Void
    let onStorageChange: () -> Void
    let onOpenStorageLocation: () -> Void
    let onFormatChange: () -> Void
    let onAppearanceChange: () -> Void
    let onLaunchAtLoginChange: () -> Void

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            styleSettings
                .tabItem {
                    Label("样式", systemImage: "paintbrush")
                }

            shortcutSettings
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }
        }
        .frame(width: 540, height: 430)
        .background(FloatingSettingsWindowAccessor())
        .onChange(of: settings.hotKey) { _, _ in
            onHotKeyChange()
        }
        .onChange(of: settings.attachment) { _, _ in
            onAttachmentChange()
        }
        .onChange(of: settings.storageDirectoryPath) { _, _ in
            onStorageChange()
        }
        .onChange(of: settings.noteFormat) { _, _ in
            onFormatChange()
        }
        .onChange(of: settings.appearance) { _, _ in
            onAppearanceChange()
        }
        .onChange(of: settings.launchAtLoginEnabled) { _, _ in
            onLaunchAtLoginChange()
        }
    }

    private var generalSettings: some View {
        VStack(spacing: 0) {
            SettingsForm {
                Section {
                    SettingsToggleRow(title: "开机自启", isOn: $settings.launchAtLoginEnabled)

                    SettingsSegmentedRow(title: "默认吸附位置") {
                        Picker("默认吸附位置", selection: $settings.attachment) {
                            ForEach(PanelAttachment.allCases) { attachment in
                                Text(attachment.title)
                                    .tag(attachment)
                            }
                        }
                    }

                    SettingsSegmentedRow(title: "保存格式") {
                        Picker("保存格式", selection: $settings.noteFormat) {
                            ForEach(NoteFormat.allCases) { format in
                                Text(format.shortTitle)
                                    .tag(format)
                            }
                        }
                    }
                }

                Section {
                    SettingsStorageRow(
                        path: settings.storageDirectoryPath,
                        onChoose: chooseStorageDirectory,
                        onOpen: onOpenStorageLocation
                    )
                }
            }

            Text("MinNote · by Felix")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.48))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)
        }
    }

    private var styleSettings: some View {
        SettingsForm {
            Section {
                SettingsSegmentedRow(title: "外观") {
                    Picker("外观", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title)
                                .tag(appearance)
                        }
                    }
                }

                SettingsSegmentedRow(title: "主题") {
                    Picker("主题", selection: $settings.visualTheme) {
                        ForEach(AppVisualTheme.allCases) { theme in
                            Text(theme.title)
                                .tag(theme)
                        }
                    }
                }

                SettingsSegmentedRow(title: "模式") {
                    Picker("模式", selection: $settings.tagDisplayMode) {
                        ForEach(TagDisplayMode.allCases) { mode in
                            Text(mode.title)
                                .tag(mode)
                        }
                    }
                }

                SettingsSegmentedRow(title: "操作区") {
                    Picker("操作区", selection: $settings.markdownToolbarEnabled) {
                        Text("开启")
                            .tag(true)
                        Text("关闭")
                            .tag(false)
                    }
                }

                if settings.markdownToolbarEnabled {
                    SettingsSegmentedRow(title: "操作区位置") {
                        Picker("操作区位置", selection: $settings.markdownToolbarPosition) {
                            ForEach(MarkdownToolbarPosition.allCases) { position in
                                Text(position.title)
                                    .tag(position)
                            }
                        }
                    }
                }
            }
        }
    }

    private var shortcutSettings: some View {
        SettingsForm {
            Section {
                SettingsShortcutRow(
                    title: "唤起浮窗",
                    configuration: $settings.hotKey
                ) {
                    settings.resetHotKey()
                }

                SettingsShortcutRow(
                    title: "导航栏",
                    configuration: $settings.sidebarHotKey
                ) {
                    settings.resetSidebarHotKey()
                }

                SettingsShortcutRow(
                    title: "预览/编辑",
                    configuration: $settings.markdownPreviewHotKey
                ) {
                    settings.resetMarkdownPreviewHotKey()
                }

                SettingsShortcutRow(
                    title: "操作区显隐",
                    configuration: $settings.markdownToolbarHotKey
                ) {
                    settings.resetMarkdownToolbarHotKey()
                }

                SettingsShortcutRow(
                    title: "操作区置顶",
                    configuration: $settings.markdownToolbarTopHotKey
                ) {
                    settings.resetMarkdownToolbarTopHotKey()
                }

                SettingsShortcutRow(
                    title: "操作区置底",
                    configuration: $settings.markdownToolbarBottomHotKey
                ) {
                    settings.resetMarkdownToolbarBottomHotKey()
                }

                SettingsShortcutRow(
                    title: "上一条笔记",
                    configuration: $settings.previousNoteHotKey
                ) {
                    settings.resetPreviousNoteHotKey()
                }

                SettingsShortcutRow(
                    title: "下一条笔记",
                    configuration: $settings.nextNoteHotKey
                ) {
                    settings.resetNextNoteHotKey()
                }

                SettingsShortcutRow(
                    title: "删除笔记",
                    configuration: $settings.deleteNoteHotKey
                ) {
                    settings.resetDeleteNoteHotKey()
                }
            }

            Section {
                ForEach(MarkdownFormattingAction.allCases) { action in
                    SettingsShortcutRow(
                        title: action.settingsTitle,
                        configuration: markdownFormattingBinding(for: action)
                    ) {
                        settings.resetMarkdownFormattingHotKey(for: action)
                    }
                }
            }
        }
    }

    private func markdownFormattingBinding(
        for action: MarkdownFormattingAction
    ) -> Binding<HotKeyConfiguration> {
        Binding {
            settings.markdownFormattingHotKey(for: action)
        } set: { configuration in
            settings.setMarkdownFormattingHotKey(configuration, for: action)
        }
    }

    private func chooseStorageDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.storageDirectoryURL

        if panel.runModal() == .OK, let url = panel.url {
            settings.storageDirectoryPath = url.path
        }
    }
}

private struct SettingsForm<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Form {
            content()
        }
        .formStyle(.grouped)
    }
}

private struct SettingsSegmentedRow<Content: View>: View {
    private let controlWidth: CGFloat = 260

    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .frame(width: 104, alignment: .leading)

            Spacer()

            content()
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: controlWidth, alignment: .trailing)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .frame(width: 104, alignment: .leading)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .frame(width: 260, alignment: .trailing)
        }
    }
}

private struct SettingsShortcutRow: View {
    let title: String
    @Binding var configuration: HotKeyConfiguration
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .frame(width: 104, alignment: .leading)

            Spacer()

            HotKeyRecorderView(configuration: $configuration)
                .frame(width: 150, height: 30)

            Button("恢复默认") {
                onReset()
            }
        }
    }
}

private struct SettingsStorageRow: View {
    let path: String
    let onChoose: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("保存地址")
                .frame(width: 104, alignment: .leading)

            Text(path)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("选择...") {
                onChoose()
            }

            Button("打开") {
                onOpen()
            }
        }
    }
}

private struct FloatingSettingsWindowAccessor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configure(window: nsView.window)
        }
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var keyMonitor: Any?

        deinit {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
        }

        func configure(window: NSWindow?) {
            guard let window else {
                return
            }

            self.window = window
            window.level = .floating
            window.hidesOnDeactivate = false
            window.collectionBehavior.insert(.canJoinAllSpaces)
            installKeyMonitorIfNeeded()
        }

        private func installKeyMonitorIfNeeded() {
            guard keyMonitor == nil else {
                return
            }

            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      event.window === self.window
                else {
                    return event
                }

                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

                if modifiers == .command,
                   event.charactersIgnoringModifiers == "," || event.keyCode == 43 {
                    self.window?.close()
                    return nil
                }

                return event
            }
        }
    }
}
