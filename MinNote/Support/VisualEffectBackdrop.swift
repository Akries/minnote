import AppKit
import SwiftUI

struct VisualEffectBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active
    var isEmphasized = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = isEmphasized
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = isEmphasized
    }
}

struct TransparentLiquidBackground: View {
    var material: NSVisualEffectView.Material = .popover
    var tint: Color
    var sheen: Color
    var reflection: Color
    var topGlow: Color

    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: material)

            Rectangle()
                .fill(tint)

            LinearGradient(
                colors: [
                    sheen,
                    .clear,
                    reflection
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    topGlow,
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.screen)
        }
    }
}

enum FloatingChromeStyle {
    @ViewBuilder
    static func capsuleBackground(
        visualTheme: AppVisualTheme,
        colorScheme: ColorScheme
    ) -> some View {
        if visualTheme == .transparent {
            TransparentLiquidBackground(
                material: .popover,
                tint: colorScheme == .light
                    ? Color.white.opacity(0.058)
                    : Color.black.opacity(0.110),
                sheen: colorScheme == .light
                    ? Color.white.opacity(0.30)
                    : Color.white.opacity(0.080),
                reflection: colorScheme == .light
                    ? MinNoteTheme.glassCoolHighlight.opacity(0.050)
                    : Color.white.opacity(0.018),
                topGlow: colorScheme == .light
                    ? Color.white.opacity(0.20)
                    : Color.white.opacity(0.060)
            )
            .clipShape(Capsule())
        } else if colorScheme == .light {
            Capsule()
                .fill(MinNoteTheme.pillSurface.opacity(0.95))
        } else {
            Capsule()
                .fill(.regularMaterial)
        }
    }

    static func borderColor(
        visualTheme: AppVisualTheme,
        colorScheme: ColorScheme
    ) -> Color {
        if visualTheme == .transparent {
            colorScheme == .light
                ? Color.white.opacity(0.38)
                : Color.white.opacity(0.13)
        } else {
            Color.primary.opacity(0.08)
        }
    }

    static func shadowColor(
        visualTheme: AppVisualTheme,
        colorScheme: ColorScheme
    ) -> Color {
        if visualTheme == .transparent {
            colorScheme == .light
                ? Color.black.opacity(0.045)
                : Color.black.opacity(0.16)
        } else {
            Color.black.opacity(0.08)
        }
    }
}

private struct FloatingCapsuleChromeModifier: ViewModifier {
    let visualTheme: AppVisualTheme
    let colorScheme: ColorScheme
    var shadowRadius: CGFloat = 8
    var shadowY: CGFloat = 3

    func body(content: Content) -> some View {
        content
            .background {
                FloatingChromeStyle.capsuleBackground(
                    visualTheme: visualTheme,
                    colorScheme: colorScheme
                )
            }
            .overlay {
                Capsule()
                    .stroke(
                        FloatingChromeStyle.borderColor(
                            visualTheme: visualTheme,
                            colorScheme: colorScheme
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: FloatingChromeStyle.shadowColor(
                    visualTheme: visualTheme,
                    colorScheme: colorScheme
                ),
                radius: shadowRadius,
                y: shadowY
            )
    }
}

extension View {
    func floatingCapsuleChrome(
        visualTheme: AppVisualTheme,
        colorScheme: ColorScheme,
        shadowRadius: CGFloat = 8,
        shadowY: CGFloat = 3
    ) -> some View {
        modifier(
            FloatingCapsuleChromeModifier(
                visualTheme: visualTheme,
                colorScheme: colorScheme,
                shadowRadius: shadowRadius,
                shadowY: shadowY
            )
        )
    }
}
