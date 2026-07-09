import AppKit
import Carbon.HIToolbox
import Foundation

struct HotKeyConfiguration: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_L),
        modifiers: UInt32(optionKey)
    )

    static let sidebarDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_Period),
        modifiers: UInt32(cmdKey)
    )

    static let sidebarModeDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_Semicolon),
        modifiers: UInt32(cmdKey)
    )

    static let markdownPreviewDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_Slash),
        modifiers: UInt32(cmdKey)
    )

    static let markdownToolbarDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_Quote),
        modifiers: UInt32(cmdKey)
    )

    static let markdownToolbarTopDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_UpArrow),
        modifiers: UInt32(cmdKey)
    )

    static let markdownToolbarBottomDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_DownArrow),
        modifiers: UInt32(cmdKey)
    )

    static let previousNoteDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_LeftArrow),
        modifiers: UInt32(cmdKey)
    )

    static let nextNoteDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_RightArrow),
        modifiers: UInt32(cmdKey)
    )

    static let deleteNoteDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_Delete),
        modifiers: UInt32(cmdKey)
    )

    static func markdownDefault(for action: MarkdownFormattingAction) -> HotKeyConfiguration {
        switch action {
        case .body:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_0), modifiers: UInt32(cmdKey))
        case .heading1:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(cmdKey))
        case .heading2:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey))
        case .heading3:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_3), modifiers: UInt32(cmdKey))
        case .bold:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey))
        case .italic:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_I), modifiers: UInt32(cmdKey))
        case .strikethrough:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_X), modifiers: UInt32(cmdKey) | UInt32(shiftKey))
        case .bulletList:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_8), modifiers: UInt32(cmdKey) | UInt32(optionKey))
        case .numberedList:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_7), modifiers: UInt32(cmdKey) | UInt32(optionKey))
        case .taskList:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(cmdKey) | UInt32(shiftKey))
        case .quote:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_Period), modifiers: UInt32(cmdKey) | UInt32(optionKey))
        case .inlineCode:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(cmdKey))
        case .codeBlock:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey) | UInt32(optionKey))
        case .table:
            return HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey) | UInt32(optionKey))
        }
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        guard event.keyCode != UInt16(kVK_Escape) else {
            return nil
        }

        self.keyCode = UInt32(event.keyCode)
        self.modifiers = Self.carbonModifiers(from: event.modifierFlags)
    }

    var displayString: String {
        "\(modifierDisplay)\(Self.keyDisplay(for: keyCode))"
    }

    func matches(event: NSEvent) -> Bool {
        keyCode == UInt32(event.keyCode)
            && modifiers == Self.carbonModifiers(from: event.modifierFlags)
    }

    private var modifierDisplay: String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("^")
        }

        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }

        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }

        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        return parts.joined()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let normalizedFlags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0

        if normalizedFlags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        if normalizedFlags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }

        if normalizedFlags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        if normalizedFlags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        return modifiers
    }

    static func keyDisplay(for keyCode: UInt32) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }

    private static let keyNames: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_ANSI_Quote): "'",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Delete): "Delete",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12"
    ]
}
