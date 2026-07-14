import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var hotKey: HotKeyConfiguration {
        didSet {
            saveHotKey()
        }
    }

    @Published var sidebarHotKey: HotKeyConfiguration {
        didSet {
            saveSidebarHotKey()
        }
    }

    @Published var sidebarModeHotKey: HotKeyConfiguration {
        didSet {
            saveSidebarModeHotKey()
        }
    }

    @Published var editorSearchHotKey: HotKeyConfiguration {
        didSet {
            saveEditorSearchHotKey()
        }
    }

    @Published var markdownPreviewHotKey: HotKeyConfiguration {
        didSet {
            saveMarkdownPreviewHotKey()
        }
    }

    @Published var markdownToolbarHotKey: HotKeyConfiguration {
        didSet {
            saveMarkdownToolbarHotKey()
        }
    }

    @Published var markdownToolbarTopHotKey: HotKeyConfiguration {
        didSet {
            saveMarkdownToolbarTopHotKey()
        }
    }

    @Published var markdownToolbarBottomHotKey: HotKeyConfiguration {
        didSet {
            saveMarkdownToolbarBottomHotKey()
        }
    }

    @Published var previousNoteHotKey: HotKeyConfiguration {
        didSet {
            savePreviousNoteHotKey()
        }
    }

    @Published var nextNoteHotKey: HotKeyConfiguration {
        didSet {
            saveNextNoteHotKey()
        }
    }

    @Published var deleteNoteHotKey: HotKeyConfiguration {
        didSet {
            saveDeleteNoteHotKey()
        }
    }

    @Published private var markdownFormattingHotKeys: [MarkdownFormattingAction: HotKeyConfiguration] {
        didSet {
            saveMarkdownFormattingHotKeys()
        }
    }

    @Published var attachment: PanelAttachment {
        didSet {
            saveAttachment()
        }
    }

    @Published var storageDirectoryPath: String {
        didSet {
            saveStorageDirectoryPath()
        }
    }

    @Published var noteFormat: NoteFormat {
        didSet {
            saveNoteFormat()
        }
    }

    @Published var appearance: AppAppearance {
        didSet {
            saveAppearance()
        }
    }

    @Published var visualTheme: AppVisualTheme {
        didSet {
            saveVisualTheme()
            // A theme supplies the initial button treatment, but an explicit
            // button-style choice is an override and must survive later theme
            // changes.
            if !userDefaults.bool(forKey: buttonStyleCustomizedKey) {
                applyDefaultButtonStyleForTheme()
            }
        }
    }

    @Published var buttonStyle: AppButtonStyle {
        didSet {
            saveButtonStyle()
        }
    }

    @Published var tagDisplayMode: TagDisplayMode {
        didSet {
            saveTagDisplayMode()
        }
    }

    @Published var markdownToolbarEnabled: Bool {
        didSet {
            saveMarkdownToolbarEnabled()
        }
    }

    @Published var markdownToolbarPosition: MarkdownToolbarPosition {
        didSet {
            saveMarkdownToolbarPosition()
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            saveLaunchAtLoginEnabled()
        }
    }

    private let userDefaults: UserDefaults
    private var isApplyingThemeButtonStyleDefault = false
    private let keyCodeKey = "hotKey.keyCode"
    private let modifiersKey = "hotKey.modifiers"
    private let sidebarKeyCodeKey = "sidebarHotKey.keyCode"
    private let sidebarModifiersKey = "sidebarHotKey.modifiers"
    private let sidebarModeKeyCodeKey = "sidebarModeHotKey.keyCode"
    private let sidebarModeModifiersKey = "sidebarModeHotKey.modifiers"
    private let editorSearchKeyCodeKey = "editorSearchHotKey.keyCode"
    private let editorSearchModifiersKey = "editorSearchHotKey.modifiers"
    private let markdownPreviewKeyCodeKey = "markdownPreviewHotKey.keyCode"
    private let markdownPreviewModifiersKey = "markdownPreviewHotKey.modifiers"
    private let markdownToolbarKeyCodeKey = "markdownToolbarHotKey.keyCode"
    private let markdownToolbarModifiersKey = "markdownToolbarHotKey.modifiers"
    private let markdownToolbarTopKeyCodeKey = "markdownToolbarTopHotKey.keyCode"
    private let markdownToolbarTopModifiersKey = "markdownToolbarTopHotKey.modifiers"
    private let markdownToolbarBottomKeyCodeKey = "markdownToolbarBottomHotKey.keyCode"
    private let markdownToolbarBottomModifiersKey = "markdownToolbarBottomHotKey.modifiers"
    private let previousNoteKeyCodeKey = "previousNoteHotKey.keyCode"
    private let previousNoteModifiersKey = "previousNoteHotKey.modifiers"
    private let nextNoteKeyCodeKey = "nextNoteHotKey.keyCode"
    private let nextNoteModifiersKey = "nextNoteHotKey.modifiers"
    private let deleteNoteKeyCodeKey = "deleteNoteHotKey.keyCode"
    private let deleteNoteModifiersKey = "deleteNoteHotKey.modifiers"
    private let markdownFormattingKeyPrefix = "markdownFormattingHotKey"
    private let attachmentKey = "panel.attachment"
    private let storageDirectoryPathKey = "storage.directoryPath"
    private let noteFormatKey = "note.format"
    private let appearanceKey = "appearance"
    private let visualThemeKey = "visualTheme"
    private let buttonStyleKey = "buttonStyle"
    private let buttonStyleCustomizedKey = "buttonStyle.customized"
    private let tagDisplayModeKey = "tagDisplayMode"
    private let markdownToolbarEnabledKey = "markdownToolbar.enabled"
    private let markdownToolbarPositionKey = "markdownToolbar.position"
    private let launchAtLoginKey = "launchAtLogin.enabled"
    private let sidebarDefaultAppliedKey = "sidebarCollapsed.defaultApplied.v2"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        userDefaults.register(defaults: ["sidebarCollapsed": true])

        if userDefaults.object(forKey: sidebarDefaultAppliedKey) == nil {
            userDefaults.set(true, forKey: "sidebarCollapsed")
            userDefaults.set(true, forKey: sidebarDefaultAppliedKey)
        }

        if userDefaults.object(forKey: keyCodeKey) == nil {
            self.hotKey = .default
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: keyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: modifiersKey))
            self.hotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: sidebarKeyCodeKey) == nil {
            self.sidebarHotKey = .sidebarDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: sidebarKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: sidebarModifiersKey))
            self.sidebarHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: sidebarModeKeyCodeKey) == nil {
            self.sidebarModeHotKey = .sidebarModeDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: sidebarModeKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: sidebarModeModifiersKey))
            self.sidebarModeHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: editorSearchKeyCodeKey) == nil {
            self.editorSearchHotKey = .editorSearchDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: editorSearchKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: editorSearchModifiersKey))
            self.editorSearchHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: markdownPreviewKeyCodeKey) == nil {
            self.markdownPreviewHotKey = .markdownPreviewDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: markdownPreviewKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: markdownPreviewModifiersKey))
            self.markdownPreviewHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: markdownToolbarKeyCodeKey) == nil {
            self.markdownToolbarHotKey = .markdownToolbarDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: markdownToolbarKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: markdownToolbarModifiersKey))
            self.markdownToolbarHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: markdownToolbarTopKeyCodeKey) == nil {
            self.markdownToolbarTopHotKey = .markdownToolbarTopDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: markdownToolbarTopKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: markdownToolbarTopModifiersKey))
            self.markdownToolbarTopHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: markdownToolbarBottomKeyCodeKey) == nil {
            self.markdownToolbarBottomHotKey = .markdownToolbarBottomDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: markdownToolbarBottomKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: markdownToolbarBottomModifiersKey))
            self.markdownToolbarBottomHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: previousNoteKeyCodeKey) == nil {
            self.previousNoteHotKey = .previousNoteDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: previousNoteKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: previousNoteModifiersKey))
            self.previousNoteHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: nextNoteKeyCodeKey) == nil {
            self.nextNoteHotKey = .nextNoteDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: nextNoteKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: nextNoteModifiersKey))
            self.nextNoteHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        if userDefaults.object(forKey: deleteNoteKeyCodeKey) == nil {
            self.deleteNoteHotKey = .deleteNoteDefault
        } else {
            let keyCode = UInt32(userDefaults.integer(forKey: deleteNoteKeyCodeKey))
            let modifiers = UInt32(userDefaults.integer(forKey: deleteNoteModifiersKey))
            self.deleteNoteHotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }

        var markdownFormattingHotKeys: [MarkdownFormattingAction: HotKeyConfiguration] = [:]
        for action in MarkdownFormattingAction.allCases {
            markdownFormattingHotKeys[action] = Self.loadHotKey(
                actionKeyPrefix: "\(markdownFormattingKeyPrefix).\(action.rawValue)",
                defaultConfiguration: .markdownDefault(for: action),
                userDefaults: userDefaults
            )
        }
        self.markdownFormattingHotKeys = markdownFormattingHotKeys

        if let rawAttachment = userDefaults.string(forKey: attachmentKey),
           let attachment = PanelAttachment(rawValue: rawAttachment) {
            self.attachment = attachment
        } else {
            self.attachment = .right
        }

        if let storageDirectoryPath = userDefaults.string(forKey: storageDirectoryPathKey),
           !storageDirectoryPath.isEmpty {
            self.storageDirectoryPath = storageDirectoryPath
        } else {
            self.storageDirectoryPath = Self.defaultStorageDirectory.path
        }

        if let rawNoteFormat = userDefaults.string(forKey: noteFormatKey),
           let noteFormat = NoteFormat(rawValue: rawNoteFormat) {
            self.noteFormat = noteFormat
        } else {
            self.noteFormat = .text
        }

        if let rawAppearance = userDefaults.string(forKey: appearanceKey),
           let appearance = AppAppearance(rawValue: rawAppearance) {
            self.appearance = appearance
        } else {
            self.appearance = .system
        }

        let resolvedVisualTheme: AppVisualTheme
        if let rawVisualTheme = userDefaults.string(forKey: visualThemeKey),
           let visualTheme = AppVisualTheme(rawValue: rawVisualTheme) {
            resolvedVisualTheme = visualTheme
        } else {
            resolvedVisualTheme = .standard
        }
        self.visualTheme = resolvedVisualTheme

        if userDefaults.bool(forKey: buttonStyleCustomizedKey),
           let rawButtonStyle = userDefaults.string(forKey: buttonStyleKey),
           let buttonStyle = AppButtonStyle(rawValue: rawButtonStyle) {
            self.buttonStyle = buttonStyle
        } else {
            self.buttonStyle = Self.defaultButtonStyle(for: resolvedVisualTheme)
        }

        if let rawTagDisplayMode = userDefaults.string(forKey: tagDisplayModeKey),
           let tagDisplayMode = TagDisplayMode(rawValue: rawTagDisplayMode) {
            self.tagDisplayMode = tagDisplayMode
        } else {
            self.tagDisplayMode = .tags
        }

        if userDefaults.object(forKey: markdownToolbarEnabledKey) == nil {
            self.markdownToolbarEnabled = true
        } else {
            self.markdownToolbarEnabled = userDefaults.bool(forKey: markdownToolbarEnabledKey)
        }

        if let rawMarkdownToolbarPosition = userDefaults.string(forKey: markdownToolbarPositionKey),
           let markdownToolbarPosition = MarkdownToolbarPosition(rawValue: rawMarkdownToolbarPosition) {
            self.markdownToolbarPosition = markdownToolbarPosition
        } else {
            self.markdownToolbarPosition = .bottom
        }

        if userDefaults.object(forKey: launchAtLoginKey) == nil {
            self.launchAtLoginEnabled = false
        } else {
            self.launchAtLoginEnabled = userDefaults.bool(forKey: launchAtLoginKey)
        }
    }

    var storageDirectoryURL: URL {
        URL(fileURLWithPath: storageDirectoryPath, isDirectory: true)
    }

    func resetHotKey() {
        hotKey = .default
    }

    func resetSidebarHotKey() {
        sidebarHotKey = .sidebarDefault
    }

    func resetSidebarModeHotKey() {
        sidebarModeHotKey = .sidebarModeDefault
    }

    func resetEditorSearchHotKey() {
        editorSearchHotKey = .editorSearchDefault
    }

    func resetMarkdownPreviewHotKey() {
        markdownPreviewHotKey = .markdownPreviewDefault
    }

    func resetMarkdownToolbarHotKey() {
        markdownToolbarHotKey = .markdownToolbarDefault
    }

    func resetMarkdownToolbarTopHotKey() {
        markdownToolbarTopHotKey = .markdownToolbarTopDefault
    }

    func resetMarkdownToolbarBottomHotKey() {
        markdownToolbarBottomHotKey = .markdownToolbarBottomDefault
    }

    func resetPreviousNoteHotKey() {
        previousNoteHotKey = .previousNoteDefault
    }

    func resetNextNoteHotKey() {
        nextNoteHotKey = .nextNoteDefault
    }

    func resetDeleteNoteHotKey() {
        deleteNoteHotKey = .deleteNoteDefault
    }

    func resetButtonStyleForTheme() {
        userDefaults.set(false, forKey: buttonStyleCustomizedKey)
        applyDefaultButtonStyleForTheme()
    }

    func markdownFormattingHotKey(for action: MarkdownFormattingAction) -> HotKeyConfiguration {
        markdownFormattingHotKeys[action] ?? .markdownDefault(for: action)
    }

    func setMarkdownFormattingHotKey(
        _ configuration: HotKeyConfiguration,
        for action: MarkdownFormattingAction
    ) {
        var updated = markdownFormattingHotKeys
        updated[action] = configuration
        markdownFormattingHotKeys = updated
    }

    func resetMarkdownFormattingHotKey(for action: MarkdownFormattingAction) {
        setMarkdownFormattingHotKey(.markdownDefault(for: action), for: action)
    }

    private func saveHotKey() {
        userDefaults.set(Int(hotKey.keyCode), forKey: keyCodeKey)
        userDefaults.set(Int(hotKey.modifiers), forKey: modifiersKey)
    }

    private func saveSidebarHotKey() {
        userDefaults.set(Int(sidebarHotKey.keyCode), forKey: sidebarKeyCodeKey)
        userDefaults.set(Int(sidebarHotKey.modifiers), forKey: sidebarModifiersKey)
    }

    private func saveSidebarModeHotKey() {
        userDefaults.set(Int(sidebarModeHotKey.keyCode), forKey: sidebarModeKeyCodeKey)
        userDefaults.set(Int(sidebarModeHotKey.modifiers), forKey: sidebarModeModifiersKey)
    }

    private func saveEditorSearchHotKey() {
        userDefaults.set(Int(editorSearchHotKey.keyCode), forKey: editorSearchKeyCodeKey)
        userDefaults.set(Int(editorSearchHotKey.modifiers), forKey: editorSearchModifiersKey)
    }

    private func saveMarkdownPreviewHotKey() {
        userDefaults.set(Int(markdownPreviewHotKey.keyCode), forKey: markdownPreviewKeyCodeKey)
        userDefaults.set(Int(markdownPreviewHotKey.modifiers), forKey: markdownPreviewModifiersKey)
    }

    private func saveMarkdownToolbarHotKey() {
        userDefaults.set(Int(markdownToolbarHotKey.keyCode), forKey: markdownToolbarKeyCodeKey)
        userDefaults.set(Int(markdownToolbarHotKey.modifiers), forKey: markdownToolbarModifiersKey)
    }

    private func saveMarkdownToolbarTopHotKey() {
        userDefaults.set(Int(markdownToolbarTopHotKey.keyCode), forKey: markdownToolbarTopKeyCodeKey)
        userDefaults.set(Int(markdownToolbarTopHotKey.modifiers), forKey: markdownToolbarTopModifiersKey)
    }

    private func saveMarkdownToolbarBottomHotKey() {
        userDefaults.set(Int(markdownToolbarBottomHotKey.keyCode), forKey: markdownToolbarBottomKeyCodeKey)
        userDefaults.set(Int(markdownToolbarBottomHotKey.modifiers), forKey: markdownToolbarBottomModifiersKey)
    }

    private func savePreviousNoteHotKey() {
        userDefaults.set(Int(previousNoteHotKey.keyCode), forKey: previousNoteKeyCodeKey)
        userDefaults.set(Int(previousNoteHotKey.modifiers), forKey: previousNoteModifiersKey)
    }

    private func saveNextNoteHotKey() {
        userDefaults.set(Int(nextNoteHotKey.keyCode), forKey: nextNoteKeyCodeKey)
        userDefaults.set(Int(nextNoteHotKey.modifiers), forKey: nextNoteModifiersKey)
    }

    private func saveDeleteNoteHotKey() {
        userDefaults.set(Int(deleteNoteHotKey.keyCode), forKey: deleteNoteKeyCodeKey)
        userDefaults.set(Int(deleteNoteHotKey.modifiers), forKey: deleteNoteModifiersKey)
    }

    private func saveMarkdownFormattingHotKeys() {
        for action in MarkdownFormattingAction.allCases {
            let configuration = markdownFormattingHotKey(for: action)
            let prefix = "\(markdownFormattingKeyPrefix).\(action.rawValue)"
            userDefaults.set(Int(configuration.keyCode), forKey: "\(prefix).keyCode")
            userDefaults.set(Int(configuration.modifiers), forKey: "\(prefix).modifiers")
        }
    }

    private func saveAttachment() {
        userDefaults.set(attachment.rawValue, forKey: attachmentKey)
    }

    private func saveStorageDirectoryPath() {
        userDefaults.set(storageDirectoryPath, forKey: storageDirectoryPathKey)
    }

    private func saveNoteFormat() {
        userDefaults.set(noteFormat.rawValue, forKey: noteFormatKey)
    }

    private func saveAppearance() {
        userDefaults.set(appearance.rawValue, forKey: appearanceKey)
    }

    private func saveVisualTheme() {
        userDefaults.set(visualTheme.rawValue, forKey: visualThemeKey)
    }

    private func saveButtonStyle() {
        userDefaults.set(buttonStyle.rawValue, forKey: buttonStyleKey)
        if !isApplyingThemeButtonStyleDefault {
            userDefaults.set(true, forKey: buttonStyleCustomizedKey)
        }
    }

    private func saveTagDisplayMode() {
        userDefaults.set(tagDisplayMode.rawValue, forKey: tagDisplayModeKey)
    }

    private func saveMarkdownToolbarEnabled() {
        userDefaults.set(markdownToolbarEnabled, forKey: markdownToolbarEnabledKey)
    }

    private func saveMarkdownToolbarPosition() {
        userDefaults.set(markdownToolbarPosition.rawValue, forKey: markdownToolbarPositionKey)
    }

    private func saveLaunchAtLoginEnabled() {
        userDefaults.set(launchAtLoginEnabled, forKey: launchAtLoginKey)
    }

    private static var defaultStorageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("MinNote", isDirectory: true)
            .appendingPathComponent("Notes", isDirectory: true)
    }

    private func applyDefaultButtonStyleForTheme() {
        isApplyingThemeButtonStyleDefault = true
        userDefaults.set(false, forKey: buttonStyleCustomizedKey)
        buttonStyle = Self.defaultButtonStyle(for: visualTheme)
        isApplyingThemeButtonStyleDefault = false
    }

    private static func defaultButtonStyle(for visualTheme: AppVisualTheme) -> AppButtonStyle {
        switch visualTheme {
        case .standard:
            return .standard
        case .glass:
            return .glass
        case .transparent:
            return .transparent
        }
    }

    private static func loadHotKey(
        actionKeyPrefix: String,
        defaultConfiguration: HotKeyConfiguration,
        userDefaults: UserDefaults
    ) -> HotKeyConfiguration {
        let keyCodeKey = "\(actionKeyPrefix).keyCode"
        let modifiersKey = "\(actionKeyPrefix).modifiers"

        guard userDefaults.object(forKey: keyCodeKey) != nil else {
            return defaultConfiguration
        }

        return HotKeyConfiguration(
            keyCode: UInt32(userDefaults.integer(forKey: keyCodeKey)),
            modifiers: UInt32(userDefaults.integer(forKey: modifiersKey))
        )
    }
}
