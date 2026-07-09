import Foundation

enum AppButtonStyle: String, CaseIterable, Identifiable {
    case standard
    case glass
    case transparent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "默认"
        case .glass:
            return "玻璃"
        case .transparent:
            return "全透"
        }
    }
}
