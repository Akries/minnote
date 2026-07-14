import SwiftUI

struct ContentView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settings: AppSettings
    let onSidebarChange: (Bool, Bool) -> Void
    let onOpenStorageLocation: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var selectedTag: NoteTag?
    @State private var sidebarMode: SidebarMode = .notes
    @State private var outlineNavigationTarget: NoteOutlineNavigationTarget?
    @State private var editorSelectionLocation = 0
    @AppStorage("sidebarCollapsed") private var sidebarCollapsed = true
    @State private var sidebarSpaceReserved = !UserDefaults.standard.bool(forKey: "sidebarCollapsed")
    @State private var sidebarTransitionID = 0
    @State private var measuredContentSize = CGSize.zero
    @State private var frozenEditorWidth: CGFloat?
    private let expandedSidebarWidth: CGFloat = 236
    private let sidebarDividerWidth: CGFloat = 1
    private let sidebarAnimationDuration: TimeInterval = 0.16
    private let sidebarAnimation: Animation = .easeOut(duration: 0.16)

    private var sidebarReservedWidth: CGFloat {
        expandedSidebarWidth + sidebarDividerWidth
    }

    private var filteredNotes: [PlainNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagFilteredNotes = store.notes.filter { note in
            guard settings.tagDisplayMode == .tags,
                  let selectedTag
            else {
                return true
            }

            return note.tag == selectedTag
        }

        guard !query.isEmpty else {
            return tagFilteredNotes
        }

        return tagFilteredNotes.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.text.localizedCaseInsensitiveContains(query)
        }
    }

    private var tagSignature: String {
        store.notes
            .map { "\($0.id.uuidString):\($0.tag?.rawValue ?? "-")" }
            .joined(separator: "|")
    }

    private var selectedOutlineItems: [NoteOutlineItem] {
        store.selectedNote?.outlineItems ?? []
    }

    private var activeOutlineItemID: String? {
        selectedOutlineItems
            .last { $0.location <= editorSelectionLocation }?
            .id
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                windowBackground
                    .ignoresSafeArea(.container, edges: .top)

                contentLayers(in: geometry.size)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .onAppear {
                measuredContentSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                measuredContentSize = newSize
            }
        }
        .onAppear {
            sidebarSpaceReserved = !sidebarCollapsed
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            setSidebarCollapsed(!sidebarCollapsed)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarMode)) { _ in
            toggleSidebarMode()
        }
        .onChange(of: selectedTag) { _, _ in
            selectFirstVisibleNoteIfNeeded()
        }
        .onChange(of: tagSignature) { _, _ in
            guard selectedTag != nil else {
                return
            }

            selectFirstVisibleNoteIfNeeded()
        }
        .onChange(of: settings.tagDisplayMode) { _, newValue in
            if newValue == .compact {
                selectedTag = nil
            }
        }
        .onChange(of: store.selectedNoteID) { _, _ in
            outlineNavigationTarget = nil
            editorSelectionLocation = 0
        }
        .frame(
            minWidth: 220,
            minHeight: 360,
            idealHeight: 460
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if settings.visualTheme == .transparent {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .light ? 0.46 : 0.20),
                                .white.opacity(0.10),
                                MinNoteTheme.glassCoolHighlight.opacity(colorScheme == .light ? 0.16 : 0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private func contentLayers(in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            editorLayer(in: size)

            if sidebarSpaceReserved {
                sidebarLayer(in: size)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .ignoresSafeArea(.container, edges: .top)
    }

    private func editorLayer(in size: CGSize) -> some View {
        let offset = editorOffsetX(in: size)

        return NoteEditorView(
            store: store,
            settings: settings,
            note: store.selectedNote,
            sidebarCollapsed: sidebarCollapsedBinding,
            outlineNavigationTarget: outlineNavigationTarget,
            onSelectionLocationChange: { location in
                editorSelectionLocation = location
            }
        )
        .frame(width: editorWidth(in: size), height: size.height)
        // Move the AppKit text editor and SwiftUI chrome as one composited surface.
        .compositingGroup()
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .offset(x: offset)
        .animation(editorOffsetAnimation, value: offset)
    }

    private func sidebarLayer(in size: CGSize) -> some View {
        let hiddenOffset = hiddenSidebarOffset

        return HStack(spacing: 0) {
            SidebarView(
                store: store,
                settings: settings,
                notes: filteredNotes,
                selectedNote: store.selectedNote,
                outlineItems: selectedOutlineItems,
                activeOutlineItemID: activeOutlineItemID,
                mode: $sidebarMode,
                searchText: $searchText,
                selectedTag: $selectedTag,
                onOpenStorageLocation: onOpenStorageLocation
            ) { item in
                outlineNavigationTarget = NoteOutlineNavigationTarget(location: item.location)
            }
            .frame(width: expandedSidebarWidth, height: size.height)

            Rectangle()
                .fill(sidebarDividerColor)
                .frame(width: sidebarDividerWidth, height: size.height)
        }
        .frame(width: sidebarReservedWidth, height: size.height, alignment: .leading)
        .offset(
            x: sidebarCollapsed ? hiddenOffset.width : 0,
            y: sidebarCollapsed ? hiddenOffset.height : 0
        )
        .opacity(sidebarCollapsed ? 0 : 1)
        .allowsHitTesting(!sidebarCollapsed)
        .animation(sidebarAnimation, value: sidebarCollapsed)
        .zIndex(settings.attachment == .right ? -1 : 1)
    }

    private func editorWidth(in size: CGSize) -> CGFloat {
        if let frozenEditorWidth {
            return min(frozenEditorWidth, size.width)
        }

        guard sidebarSpaceReserved else {
            return size.width
        }

        return max(0, size.width - sidebarReservedWidth)
    }

    private func editorOffsetX(in size: CGSize) -> CGFloat {
        if let frozenEditorWidth {
            return max(0, size.width - frozenEditorWidth)
        }

        guard sidebarSpaceReserved else {
            return 0
        }

        switch settings.attachment {
        case .right:
            return sidebarReservedWidth
        case .left:
            return sidebarCollapsed ? 0 : sidebarReservedWidth
        case .bottom:
            // Keep the editor's trailing edge fixed while the sidebar enters.
            return sidebarReservedWidth
        }
    }

    private var editorOffsetAnimation: Animation? {
        guard frozenEditorWidth == nil else {
            return nil
        }

        switch settings.attachment {
        case .left:
            return sidebarAnimation
        case .right, .bottom:
            return nil
        }
    }

    private var hiddenSidebarOffset: CGSize {
        switch settings.attachment {
        case .right:
            return CGSize(width: sidebarReservedWidth, height: 0)
        case .left, .bottom:
            return CGSize(width: -sidebarReservedWidth, height: 0)
        }
    }

    @ViewBuilder
    private var windowBackground: some View {
        switch settings.visualTheme {
        case .standard:
            if colorScheme == .light {
                MinNoteTheme.windowSurface
            } else {
                Rectangle()
                    .fill(.regularMaterial)
            }
        case .glass:
            windowGlassBackground(
                material: .ultraThinMaterial,
                materialOpacity: 1,
                tint: colorScheme == .light
                    ? MinNoteTheme.windowGlassLightTint.opacity(0.22)
                    : MinNoteTheme.editorGlassDarkTint.opacity(0.36),
                sheen: colorScheme == .light ? .white.opacity(0.48) : .white.opacity(0.08),
                tail: colorScheme == .light
                    ? MinNoteTheme.glassCoolHighlight.opacity(0.06)
                    : .black.opacity(0.08)
            )
        case .transparent:
            TransparentLiquidBackground(
                material: .popover,
                tint: colorScheme == .light
                    ? Color.white.opacity(0.036)
                    : Color.black.opacity(0.082),
                sheen: colorScheme == .light
                    ? Color.white.opacity(0.20)
                    : Color.white.opacity(0.060),
                reflection: colorScheme == .light
                    ? MinNoteTheme.glassCoolHighlight.opacity(0.050)
                    : Color.white.opacity(0.018),
                topGlow: colorScheme == .light
                    ? Color.white.opacity(0.16)
                    : Color.white.opacity(0.045)
            )
        }
    }

    private func windowGlassBackground(
        material: Material,
        materialOpacity: Double,
        tint: Color,
        sheen: Color,
        tail: Color
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(material)
                .opacity(materialOpacity)

            Rectangle()
                .fill(tint)

            LinearGradient(
                colors: [sheen, .clear, tail],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var sidebarDividerColor: Color {
        colorScheme == .dark ? .black.opacity(0.22) : .black.opacity(0.08)
    }

    private var sidebarCollapsedBinding: Binding<Bool> {
        Binding {
            sidebarCollapsed
        } set: { newValue in
            setSidebarCollapsed(newValue)
        }
    }

    private func setSidebarCollapsed(_ collapsed: Bool) {
        guard collapsed != sidebarCollapsed else {
            return
        }

        sidebarTransitionID += 1
        let transitionID = sidebarTransitionID
        let animatesPanelFrame = beginPanelFrameTransitionIfNeeded()

        if collapsed {
            withAnimation(sidebarAnimation) {
                sidebarCollapsed = true
            }
            onSidebarChange(true, animatesPanelFrame)

            DispatchQueue.main.asyncAfter(deadline: .now() + sidebarAnimationDuration) {
                guard transitionID == sidebarTransitionID else {
                    return
                }

                setSidebarSpaceReserved(false)
                finishPanelFrameTransition()
            }
        } else {
            setSidebarSpaceReserved(true)
            onSidebarChange(false, animatesPanelFrame)

            DispatchQueue.main.async {
                guard transitionID == sidebarTransitionID else {
                    return
                }

                withAnimation(sidebarAnimation) {
                    sidebarCollapsed = false
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + sidebarAnimationDuration) {
                guard transitionID == sidebarTransitionID else {
                    return
                }

                finishPanelFrameTransition()
            }
        }
    }

    private func beginPanelFrameTransitionIfNeeded() -> Bool {
        guard settings.attachment != .bottom,
              measuredContentSize.width > 0
        else {
            return false
        }

        frozenEditorWidth = editorWidth(in: measuredContentSize)
        return true
    }

    private func finishPanelFrameTransition() {
        frozenEditorWidth = nil
    }

    private func setSidebarSpaceReserved(_ isReserved: Bool) {
        var transaction = Transaction()
        transaction.animation = nil
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            sidebarSpaceReserved = isReserved
        }
    }

    private func toggleSidebarMode() {
        if sidebarCollapsed {
            setSidebarCollapsed(false)
            sidebarMode = .outline
            return
        }

        sidebarMode = sidebarMode.toggled
    }

    private func selectFirstVisibleNoteIfNeeded() {
        guard let firstNote = filteredNotes.first,
              !filteredNotes.contains(where: { $0.id == store.selectedNoteID })
        else {
            return
        }

        store.select(firstNote)
    }
}
