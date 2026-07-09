import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settings: AppSettings
    let onSidebarChange: (Bool) -> Void
    let onOpenStorageLocation: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var selectedTag: NoteTag?
    @State private var sidebarMode: SidebarMode = .notes
    @State private var outlineNavigationTarget: NoteOutlineNavigationTarget?
    @State private var editorSelectionLocation = 0
    @AppStorage("sidebarCollapsed") private var sidebarCollapsed = true

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
        HStack(spacing: 0) {
            if !sidebarCollapsed {
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
                .frame(width: 210)

                Rectangle()
                    .fill(sidebarDividerColor)
                    .frame(width: 1)
            }

            NoteEditorView(
                store: store,
                settings: settings,
                note: store.selectedNote,
                sidebarCollapsed: sidebarCollapsedBinding,
                outlineNavigationTarget: outlineNavigationTarget,
                onSelectionLocationChange: { location in
                    editorSelectionLocation = location
                }
            )
        }
        .transaction { transaction in
            transaction.animation = nil
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
        .background(windowBackground)
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

        var transaction = Transaction()
        transaction.animation = nil

        onSidebarChange(collapsed)
        withTransaction(transaction) {
            sidebarCollapsed = collapsed
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
