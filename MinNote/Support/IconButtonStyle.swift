import SwiftUI

struct IconButtonStyle: ButtonStyle {
    let buttonStyle: AppButtonStyle
    let visualTheme: AppVisualTheme

    @Environment(\.colorScheme) private var colorScheme

    init(
        buttonStyle: AppButtonStyle = .standard,
        visualTheme: AppVisualTheme = .standard
    ) {
        self.buttonStyle = buttonStyle
        self.visualTheme = visualTheme
    }

    func makeBody(configuration: Configuration) -> some View {
        IconButtonChrome(
            isPressed: configuration.isPressed,
            buttonStyle: buttonStyle,
            visualTheme: visualTheme,
            colorScheme: colorScheme
        ) {
            configuration.label
        }
    }
}

private struct IconButtonChrome<Label: View>: View {
    let isPressed: Bool
    let buttonStyle: AppButtonStyle
    let visualTheme: AppVisualTheme
    let colorScheme: ColorScheme
    private let label: Label

    init(
        isPressed: Bool,
        buttonStyle: AppButtonStyle,
        visualTheme: AppVisualTheme,
        colorScheme: ColorScheme,
        @ViewBuilder label: () -> Label
    ) {
        self.isPressed = isPressed
        self.buttonStyle = buttonStyle
        self.visualTheme = visualTheme
        self.colorScheme = colorScheme
        self.label = label()
    }

    var body: some View {
        label
            .foregroundStyle(.primary.opacity(isPressed ? 0.62 : 0.86))
            .frame(width: 28, height: 28)
            .background {
                background
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        switch buttonStyle {
        case .standard:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(isPressed ? 0.12 : 0.055))
        case .glass:
            glassBackground
        case .transparent:
            transparentBackground
        }
    }

    @ViewBuilder
    private var glassBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: shape)
                .opacity(isPressed ? 0.86 : 1)
        } else {
            TransparentLiquidBackground(
                material: .popover,
                tint: colorScheme == .light
                    ? Color.white.opacity(0.050)
                    : Color.black.opacity(0.095),
                sheen: colorScheme == .light
                    ? Color.white.opacity(0.28)
                    : Color.white.opacity(0.075),
                reflection: colorScheme == .light
                    ? MinNoteTheme.glassCoolHighlight.opacity(0.050)
                    : Color.white.opacity(0.018),
                topGlow: colorScheme == .light
                    ? Color.white.opacity(0.19)
                    : Color.white.opacity(0.055)
            )
            .clipShape(shape)
            .overlay {
                shape
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
                radius: isPressed ? 3 : 8,
                y: isPressed ? 1 : 3
            )
        }
    }

    @ViewBuilder
    private var transparentBackground: some View {
        FloatingChromeStyle.capsuleBackground(
            visualTheme: .transparent,
            colorScheme: colorScheme
        )
        .overlay {
            Capsule()
                .stroke(
                    FloatingChromeStyle.borderColor(
                        visualTheme: .transparent,
                        colorScheme: colorScheme
                    ),
                    lineWidth: 1
                )
        }
        .shadow(
            color: FloatingChromeStyle.shadowColor(
                visualTheme: .transparent,
                colorScheme: colorScheme
            ),
            radius: 8,
            y: 3
        )
    }
}
