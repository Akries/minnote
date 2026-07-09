import AppKit
import SwiftUI

enum NoteTag: String, CaseIterable, Codable, Identifiable, Hashable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .red:
            return "红色"
        case .orange:
            return "橙色"
        case .yellow:
            return "黄色"
        case .green:
            return "绿色"
        case .blue:
            return "蓝色"
        case .purple:
            return "紫色"
        }
    }

    var color: Color {
        switch self {
        case .red:
            return Self.adaptiveColor(light: (0xEC, 0x3E, 0x46), dark: (0xFF, 0x5A, 0x67))
        case .orange:
            return Self.adaptiveColor(light: (0xF1, 0x8F, 0x2A), dark: (0xFF, 0xA1, 0x3D))
        case .yellow:
            return Self.adaptiveColor(light: (0xE9, 0xBB, 0x2E), dark: (0xF8, 0xD6, 0x4D))
        case .green:
            return Self.adaptiveColor(light: (0x35, 0xC9, 0x63), dark: (0x42, 0xD6, 0x75))
        case .blue:
            return Self.adaptiveColor(light: (0x46, 0x7A, 0xEC), dark: (0x5A, 0xA9, 0xFF))
        case .purple:
            return Self.adaptiveColor(light: (0x8F, 0x65, 0xDF), dark: (0xB4, 0x7C, 0xFF))
        }
    }

    private static func adaptiveColor(
        light: (Int, Int, Int),
        dark: (Int, Int, Int)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let components = isDark ? dark : light

            return NSColor(
                calibratedRed: CGFloat(components.0) / 255,
                green: CGFloat(components.1) / 255,
                blue: CGFloat(components.2) / 255,
                alpha: 1
            )
        })
    }
}
