import AppKit
import SwiftUI

enum SidebarMode: String, CaseIterable, Identifiable {
    case notes
    case outline

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .notes:
            return "note.text"
        case .outline:
            return "list.bullet.indent"
        }
    }

    var help: String {
        switch self {
        case .notes:
            return "笔记列表"
        case .outline:
            return "大纲"
        }
    }

    var toggled: SidebarMode {
        switch self {
        case .notes:
            return .outline
        case .outline:
            return .notes
        }
    }

    var toggleHelp: String {
        "切换到\(toggled.help)"
    }
}

struct SidebarView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settings: AppSettings
    let notes: [PlainNote]
    let selectedNote: PlainNote?
    let outlineItems: [NoteOutlineItem]
    @Binding var mode: SidebarMode
    @Binding var searchText: String
    @Binding var selectedTag: NoteTag?
    let onSelectOutlineItem: (NoteOutlineItem) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    private let trafficLightContentInset: CGFloat = 62

    var body: some View {
        VStack(spacing: 12) {
            header

            switch mode {
            case .notes:
                searchField
                if settings.tagDisplayMode == .tags {
                    tagFilter
                }
                notesList
                footer
            case .outline:
                outlineHeader
                outlineList
            }
        }
        .padding(14)
        .background {
            switch settings.visualTheme {
            case .standard:
                sidebarGlassBackground(
                    material: .regularMaterial,
                    materialOpacity: 1,
                    tint: colorScheme == .light
                        ? MinNoteTheme.sidebarGlassLightTint.opacity(0.90)
                        : MinNoteTheme.sidebarGlassDarkTint.opacity(0.72),
                    sheen: colorScheme == .light ? .white.opacity(0.42) : .white.opacity(0.07),
                    border: colorScheme == .light ? .white.opacity(0.54) : .white.opacity(0.12),
                    tail: colorScheme == .light ? .black.opacity(0.015) : .black.opacity(0.08)
                )
            case .glass:
                sidebarGlassBackground(
                    material: .ultraThinMaterial,
                    materialOpacity: 1,
                    tint: colorScheme == .light
                        ? MinNoteTheme.sidebarGlassLightTint.opacity(0.14)
                        : MinNoteTheme.sidebarGlassDarkTint.opacity(0.38),
                    sheen: colorScheme == .light ? .white.opacity(0.76) : .white.opacity(0.11),
                    border: colorScheme == .light ? .white.opacity(0.54) : .white.opacity(0.16),
                    tail: colorScheme == .light
                        ? MinNoteTheme.glassCoolHighlight.opacity(0.035)
                        : .black.opacity(0.08)
                )
            case .transparent:
                transparentSidebarBackground(
                    tint: colorScheme == .light
                        ? Color.white.opacity(0.052)
                        : Color.black.opacity(0.095),
                    sheen: colorScheme == .light
                        ? Color.white.opacity(0.28)
                        : Color.white.opacity(0.070),
                    border: colorScheme == .light
                        ? Color.white.opacity(0.44)
                        : Color.white.opacity(0.14),
                    reflection: colorScheme == .light
                        ? MinNoteTheme.glassCoolHighlight.opacity(0.045)
                        : Color.white.opacity(0.018)
                )
            }
        }
    }

    private func sidebarGlassBackground(
        material: Material,
        materialOpacity: Double,
        tint: Color,
        sheen: Color,
        border: Color,
        tail: Color
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(material)
                .opacity(materialOpacity)

            Rectangle()
                .fill(tint)

            LinearGradient(
                colors: [
                    sheen,
                    .clear,
                    tail
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .stroke(border, lineWidth: 1)
        }
    }

    private func transparentSidebarBackground(
        tint: Color,
        sheen: Color,
        border: Color,
        reflection: Color
    ) -> some View {
        ZStack {
            TransparentLiquidBackground(
                material: .popover,
                tint: tint,
                sheen: sheen,
                reflection: reflection,
                topGlow: colorScheme == .light
                    ? Color.white.opacity(0.18)
                    : Color.white.opacity(0.052)
            )

            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [
                            border,
                            Color.white.opacity(0.08),
                            MinNoteTheme.glassCoolHighlight.opacity(colorScheme == .light ? 0.13 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("MinNote")
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Button {
                mode = mode.toggled
            } label: {
                Image(systemName: mode.toggled.systemImage)
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .help(mode.toggleHelp)
        }
        .padding(.leading, trafficLightContentInset)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField("搜索", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(0.055))
        }
    }

    private var tagFilter: some View {
        HStack(spacing: 5) {
            TagFilterButton(
                title: "全部",
                tint: .secondary,
                isSelected: selectedTag == nil
            ) {
                selectedTag = nil
            }

            ForEach(NoteTag.allCases) { tag in
                TagFilterButton(
                    title: tag.title,
                    tint: tag.color,
                    isSelected: selectedTag == tag
                ) {
                    selectedTag = tag
                }
            }
        }
        .frame(height: 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if notes.isEmpty {
                    Text("没有匹配")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                } else {
                    ForEach(notes) { note in
                        NoteRowView(
                            note: note,
                            isSelected: note.id == store.selectedNoteID,
                            showsTag: settings.tagDisplayMode == .tags
                        ) {
                            store.select(note)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            countPill

            Spacer()

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .help("设置")
        }
    }

    private var outlineHeader: some View {
        Text(selectedNote?.title ?? "无标题")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var outlineList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if outlineItems.isEmpty {
                    Text("当前笔记暂无大纲")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                } else {
                    ForEach(outlineItems) { item in
                        OutlineRowView(item: item) {
                            onSelectOutlineItem(item)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var countPill: some View {
        Text("\(notes.count) 条")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .floatingCapsuleChrome(
                visualTheme: settings.visualTheme,
                colorScheme: colorScheme
            )
    }
}

private struct OutlineRowView: View {
    let item: NoteOutlineItem
    let action: () -> Void

    private var leadingPadding: CGFloat {
        CGFloat(max(item.level - 1, 0)) * 12
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text("H\(item.level)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 18)
                    .background(.primary.opacity(0.055), in: Capsule())

                Text(item.title)
                    .font(.system(size: 12, weight: item.level == 1 ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            }
        }
        .buttonStyle(.plain)
        .help(item.title)
    }
}

private struct NoteRowView: View {
    let note: PlainNote
    let isSelected: Bool
    let showsTag: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if showsTag, let tag = note.tag {
                        Circle()
                            .fill(tag.color)
                            .frame(width: 7, height: 7)
                            .help(tag.title)
                    }

                    Text(note.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(note.format.fileExtension.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.primary.opacity(0.06), in: Capsule())

                    Text(note.updatedAt, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Text(note.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.095) : Color.clear)
            }
            .overlay {
                if isSelected {
                    AkriesFlowBorderMotion(cornerRadius: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AkriesFlowBorderMotion: View {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let metrics = motionMetrics(at: timeline.date)
            let pulse = reduceMotion ? 0.35 : metrics.pulse
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let gradient = flowGradient(angle: reduceMotion ? .degrees(18) : metrics.angle)

            ZStack {
                shape
                    .inset(by: 0.7)
                    .stroke(baseStroke, lineWidth: 1)

                shape
                    .inset(by: 1.2)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 1.15 + pulse * 0.35, lineCap: .round, lineJoin: .round))
                    .opacity(reduceMotion ? 0.70 : 0.86)

                shape
                    .inset(by: 2.7)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 1.6 + pulse * 0.65, lineCap: .round, lineJoin: .round))
                    .opacity(reduceMotion ? 0.14 : 0.08 + pulse * 0.12)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var baseStroke: Color {
        colorScheme == .light
            ? Color.white.opacity(0.72)
            : Color.white.opacity(0.16)
    }

    private func motionMetrics(at date: Date) -> (angle: Angle, pulse: CGFloat) {
        let seconds = date.timeIntervalSinceReferenceDate
        let flowProgress = seconds.truncatingRemainder(dividingBy: 4.8) / 4.8
        let pulseProgress = (sin(seconds * Double.pi * 2 / 1.65) + 1) / 2

        return (
            angle: .degrees(flowProgress * 360),
            pulse: CGFloat(pulseProgress)
        )
    }

    private func flowGradient(angle: Angle) -> AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.071, green: 0.851, blue: 1.000).opacity(0.95),
                Color(red: 0.125, green: 0.788, blue: 1.000).opacity(0.92),
                Color(red: 0.184, green: 0.490, blue: 1.000).opacity(0.98),
                Color(red: 0.435, green: 0.525, blue: 1.000).opacity(0.92),
                Color(red: 0.616, green: 0.467, blue: 1.000).opacity(0.88),
                Color(red: 0.835, green: 0.396, blue: 0.910).opacity(0.90),
                Color(red: 1.000, green: 0.310, blue: 0.741).opacity(0.92),
                Color(red: 1.000, green: 0.557, blue: 0.788).opacity(0.82),
                Color(red: 1.000, green: 0.902, blue: 0.427).opacity(0.82),
                Color(red: 0.812, green: 1.000, blue: 0.459).opacity(0.80),
                Color(red: 0.471, green: 1.000, blue: 0.549).opacity(0.86),
                Color(red: 0.071, green: 0.851, blue: 1.000).opacity(0.95)
            ],
            center: .center,
            angle: angle
        )
    }
}

private struct TagFilterButton: View {
    let title: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .opacity(title == "全部" ? 0.45 : 1)
                .frame(maxWidth: .infinity, minHeight: 22)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.16) : Color.primary.opacity(0.045))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
