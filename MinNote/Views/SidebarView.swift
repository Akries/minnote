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
            return "rectangle.stack"
        case .outline:
            return "list.bullet.indent"
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
}

struct SidebarView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settings: AppSettings
    let notes: [PlainNote]
    let selectedNote: PlainNote?
    let outlineItems: [NoteOutlineItem]
    let activeOutlineItemID: String?
    @Binding var mode: SidebarMode
    @Binding var searchText: String
    @Binding var selectedTag: NoteTag?
    let onOpenStorageLocation: () -> Void
    let onSelectOutlineItem: (NoteOutlineItem) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    @State private var collapsedH1IDs: Set<String> = []

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
        .onChange(of: selectedNote?.id) { _, _ in
            collapsedH1IDs.removeAll()
        }
        .onChange(of: outlineItems) { _, _ in
            reconcileCollapsedH1IDs()
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
            Image(systemName: "signature")
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.primary, Color.accentColor)
                .frame(width: 18)

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
        }
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
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            countPill

            Spacer()

            Button {
                onOpenStorageLocation()
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .help("打开存储位置")

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
        HStack(spacing: 6) {
            Text("大纲")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Text("\(outlineItems.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                collapseAllH1()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .disabled(h1ItemsWithChildren.isEmpty)
            .help("全部收起")

            Button {
                expandAllH1()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .disabled(collapsedH1IDs.isEmpty)
            .help("全部展开")
        }
        .frame(height: 28)
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
                    ForEach(visibleOutlineItems) { item in
                        OutlineRowView(
                            item: item,
                            hasChildren: hasOutlineChildren(item),
                            isCollapsed: collapsedH1IDs.contains(item.id),
                            isActive: item.id == activeOutlineDisplayID,
                            onToggle: {
                                toggleH1Collapse(item)
                            }
                        ) {
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

    private var h1ItemsWithChildren: [NoteOutlineItem] {
        outlineItems.filter { item in
            item.level == 1 && hasOutlineChildren(item)
        }
    }

    private var visibleOutlineItems: [NoteOutlineItem] {
        var visibleItems: [NoteOutlineItem] = []
        var collapsedH1ID: String?

        for item in outlineItems {
            if item.level == 1 {
                visibleItems.append(item)
                collapsedH1ID = collapsedH1IDs.contains(item.id) ? item.id : nil
                continue
            }

            if collapsedH1ID == nil {
                visibleItems.append(item)
            }
        }

        return visibleItems
    }

    private var activeOutlineDisplayID: String? {
        guard let activeOutlineItemID else {
            return nil
        }

        if visibleOutlineItems.contains(where: { $0.id == activeOutlineItemID }) {
            return activeOutlineItemID
        }

        guard let activeIndex = outlineItems.firstIndex(where: { $0.id == activeOutlineItemID })
        else {
            return nil
        }

        return outlineItems[..<activeIndex].last { item in
            item.level == 1 && collapsedH1IDs.contains(item.id)
        }?.id
    }

    private func hasOutlineChildren(_ item: NoteOutlineItem) -> Bool {
        guard item.level == 1,
              let index = outlineItems.firstIndex(of: item)
        else {
            return false
        }

        for nextItem in outlineItems.dropFirst(index + 1) {
            if nextItem.level <= item.level {
                return false
            }

            return true
        }

        return false
    }

    private func toggleH1Collapse(_ item: NoteOutlineItem) {
        guard hasOutlineChildren(item) else {
            return
        }

        if collapsedH1IDs.contains(item.id) {
            collapsedH1IDs.remove(item.id)
        } else {
            collapsedH1IDs.insert(item.id)
        }
    }

    private func collapseAllH1() {
        collapsedH1IDs = Set(h1ItemsWithChildren.map(\.id))
    }

    private func expandAllH1() {
        collapsedH1IDs.removeAll()
    }

    private func reconcileCollapsedH1IDs() {
        let validIDs = Set(h1ItemsWithChildren.map(\.id))
        collapsedH1IDs = collapsedH1IDs.intersection(validIDs)
    }
}

private struct OutlineRowView: View {
    let item: NoteOutlineItem
    let hasChildren: Bool
    let isCollapsed: Bool
    let isActive: Bool
    let onToggle: () -> Void
    let action: () -> Void

    private var leadingPadding: CGFloat {
        CGFloat(max(item.level - 1, 0)) * 14
    }

    private var titleFont: Font {
        switch item.level {
        case 1:
            return .system(size: 13, weight: .semibold)
        case 2:
            return .system(size: 12, weight: .medium)
        default:
            return .system(size: 12, weight: .regular)
        }
    }

    private var titleColor: Color {
        if isActive {
            return .accentColor
        }

        switch item.level {
        case 1:
            return .primary
        case 2:
            return .secondary
        default:
            return .secondary.opacity(0.78)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(width: 2, height: 16)
                .clipShape(Capsule())

            Group {
                if item.level == 1 {
                    Button(action: onToggle) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(hasChildren ? .secondary : .tertiary)
                            .frame(width: 12, height: 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasChildren)
                    .opacity(hasChildren ? 1 : 0)
                } else {
                    Color.clear
                        .frame(width: 12, height: 16)
                }
            }

            Button(action: action) {
                Text(item.title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, 4)
        .padding(.vertical, item.level == 1 ? 5 : 4)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.22), lineWidth: 1)
                            }
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
        }
        .buttonStyle(.plain)
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
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
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
