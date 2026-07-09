import AppKit
import SwiftUI

struct NoteEditorView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settings: AppSettings
    let note: PlainNote?
    @Binding var sidebarCollapsed: Bool
    let outlineNavigationTarget: NoteOutlineNavigationTarget?
    let onSelectionLocationChange: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var markdownPreviewEnabled = false
    @State private var tagPickerPresented = false
    @State private var markdownToolbarVisible = true
    @State private var markdownToolbarVisibleBeforePreview = true
    @State private var activeTextView: NSTextView?
    @State private var editorFocusToken = 0
    @State private var previewText = ""
    @State private var isPlaceholderVisible = true
    @State private var editorMoreMenuPresented = false

    var body: some View {
        VStack(spacing: 0) {
            header

            editorBody
        }
        .background(editorBackground)
        .onAppear {
            syncEditorSnapshotFromStore()
            focusEditor()
        }
        .onChange(of: store.selectedNoteID) { _, _ in
            syncEditorSnapshotFromStore()
            focusEditor()
        }
        .onChange(of: outlineNavigationTarget?.id) { _, _ in
            navigateToOutlineTarget(outlineNavigationTarget)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMarkdownPreview)) { _ in
            guard isMarkdownMode else {
                return
            }

            toggleMarkdownPreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMarkdownToolbar)) { _ in
            guard settings.markdownToolbarEnabled,
                  isMarkdownMode,
                  !markdownPreviewEnabled
            else {
                return
            }

            markdownToolbarVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .applyMarkdownFormatting)) { notification in
            guard let rawValue = notification.object as? String,
                  let action = MarkdownFormattingAction(rawValue: rawValue)
            else {
                return
            }

            applyMarkdownFormatting(action)
        }
        .onChange(of: settings.markdownToolbarEnabled) { _, isEnabled in
            if isEnabled {
                if markdownPreviewEnabled {
                    markdownToolbarVisibleBeforePreview = true
                } else {
                    markdownToolbarVisible = true
                }
            }
        }
    }

    @ViewBuilder
    private var editorBackground: some View {
        switch settings.visualTheme {
        case .glass:
            glassBackground(
                material: .ultraThinMaterial,
                materialOpacity: 1,
                tint: colorScheme == .light
                    ? MinNoteTheme.editorGlassLightTint.opacity(0.16)
                    : MinNoteTheme.editorGlassDarkTint.opacity(0.44),
                sheen: colorScheme == .light
                    ? .white.opacity(0.62)
                    : .white.opacity(0.08)
            )
        case .transparent:
            TransparentLiquidBackground(
                material: .popover,
                tint: colorScheme == .light
                    ? Color.white.opacity(0.034)
                    : Color.black.opacity(0.076),
                sheen: colorScheme == .light
                    ? Color.white.opacity(0.18)
                    : Color.white.opacity(0.052),
                reflection: colorScheme == .light
                    ? MinNoteTheme.glassCoolHighlight.opacity(0.042)
                    : Color.white.opacity(0.016),
                topGlow: colorScheme == .light
                    ? Color.white.opacity(0.14)
                    : Color.white.opacity(0.040)
            )
        case .standard:
            if colorScheme == .light {
                MinNoteTheme.editorSurface
            } else {
                Rectangle()
                    .fill(.regularMaterial)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note?.title ?? "无标题")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                sidebarCollapsed.toggle()
            } label: {
                Image(systemName: sidebarCollapsed ? "sidebar.leading" : "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle(buttonStyle: settings.buttonStyle, visualTheme: settings.visualTheme))
            .help(sidebarCollapsed ? "显示列表" : "收起列表")

            Button {
                store.createNote()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle(buttonStyle: settings.buttonStyle, visualTheme: settings.visualTheme))
            .help("新建笔记")

            ZStack {
                Button {
                    editorMoreMenuPresented.toggle()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle(buttonStyle: settings.buttonStyle, visualTheme: settings.visualTheme))
                .help("更多")

                Color.clear
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .popover(isPresented: $editorMoreMenuPresented, arrowEdge: .top) {
                        EditorMoreMenuPopover(canDeleteNote: note != nil) {
                            store.deleteSelectedNote()
                            editorMoreMenuPresented = false
                        }
                    }
            }
            .frame(width: 28, height: 28)
            .onChange(of: settings.visualTheme) { _, _ in
                editorMoreMenuPresented = false
            }
            .onChange(of: settings.buttonStyle) { _, _ in
                editorMoreMenuPresented = false
            }
            .onChange(of: colorScheme) { _, _ in
                editorMoreMenuPresented = false
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.07))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var headerBackground: some View {
        switch settings.visualTheme {
        case .glass:
            glassBackground(
                material: .ultraThinMaterial,
                materialOpacity: 1,
                tint: colorScheme == .light
                    ? MinNoteTheme.editorGlassLightTint.opacity(0.12)
                    : MinNoteTheme.editorGlassDarkTint.opacity(0.30),
                sheen: colorScheme == .light
                    ? .white.opacity(0.58)
                    : .white.opacity(0.06)
            )
        case .transparent:
            TransparentLiquidBackground(
                material: .popover,
                tint: colorScheme == .light
                    ? Color.white.opacity(0.052)
                    : Color.black.opacity(0.098),
                sheen: colorScheme == .light
                    ? Color.white.opacity(0.28)
                    : Color.white.opacity(0.070),
                reflection: colorScheme == .light
                    ? MinNoteTheme.glassCoolHighlight.opacity(0.050)
                    : Color.white.opacity(0.020),
                topGlow: colorScheme == .light
                    ? Color.white.opacity(0.18)
                    : Color.white.opacity(0.052)
            )
        case .standard:
            if colorScheme == .light {
                MinNoteTheme.headerSurface
            } else {
                Rectangle()
                    .fill(.thinMaterial.opacity(0.72))
            }
        }
    }

    private func glassBackground(
        material: Material,
        materialOpacity: Double,
        tint: Color,
        sheen: Color,
        tail: Color? = nil
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
                    tail ?? (colorScheme == .light
                        ? MinNoteTheme.glassCoolHighlight.opacity(0.045)
                        : .black.opacity(0.07))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var statusText: String {
        guard let note else {
            return "0 字"
        }

        return "\(note.characterCount) 字 · \(note.updatedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var formatLabel: String {
        switch note?.format ?? settings.noteFormat {
        case .text:
            return "TXT"
        case .markdown:
            return markdownPreviewEnabled ? "MD · 预览" : "MD · 编辑"
        }
    }

    @ViewBuilder
    private var toolbarChromeBackground: some View {
        if settings.visualTheme == .transparent {
            TransparentLiquidBackground(
                material: .popover,
                tint: colorScheme == .light
                    ? Color.white.opacity(0.060)
                    : Color.black.opacity(0.115),
                sheen: colorScheme == .light
                    ? Color.white.opacity(0.32)
                    : Color.white.opacity(0.085),
                reflection: colorScheme == .light
                    ? MinNoteTheme.glassCoolHighlight.opacity(0.055)
                    : Color.white.opacity(0.020),
                topGlow: colorScheme == .light
                    ? Color.white.opacity(0.22)
                    : Color.white.opacity(0.065)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if colorScheme == .light {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MinNoteTheme.pillSurface.opacity(0.95))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private var chromeBorderColor: Color {
        FloatingChromeStyle.borderColor(
            visualTheme: settings.visualTheme,
            colorScheme: colorScheme
        )
    }

    private var chromeShadowColor: Color {
        FloatingChromeStyle.shadowColor(
            visualTheme: settings.visualTheme,
            colorScheme: colorScheme
        )
    }

    @ViewBuilder
    private var editorBody: some View {
        if isBottomToolbarVisible {
            VStack(spacing: 0) {
                editorSurface
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomControlArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if isTopToolbarVisible {
                        markdownToolbarPanel
                            .padding(.horizontal, FloatingChromeMetrics.horizontalPadding)
                            .padding(.top, FloatingChromeMetrics.topToolbarTopPadding)
                            .padding(.bottom, FloatingChromeMetrics.topToolbarBottomPadding)
                    }

                    editorSurface
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                bottomControlArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var bottomControlArea: some View {
        VStack(spacing: 8) {
            if isBottomToolbarVisible {
                markdownToolbarPanel
            }

            HStack(alignment: .bottom) {
                HStack(spacing: 8) {
                    if settings.tagDisplayMode == .tags {
                        tagPill
                    }
                    formatPill
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)

                Spacer(minLength: 8)

                statusPill
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
            }
        }
        .padding(.horizontal, FloatingChromeMetrics.horizontalPadding)
        .padding(.top, FloatingChromeMetrics.bottomTopPadding)
        .padding(.bottom, FloatingChromeMetrics.bottomPadding)
        .frame(height: bottomFloatingChromeHeight, alignment: .bottom)
    }

    @ViewBuilder
    private var editorSurface: some View {
        if isMarkdownMode, markdownPreviewEnabled {
            MarkdownPreviewView(
                text: previewText
            ) { sourceLine in
                toggleMarkdownTask(at: sourceLine)
            }
        } else {
            ZStack(alignment: .topLeading) {
                MarkdownTextEditor(
                    noteID: note?.id,
                    text: store.selectedText,
                    focusToken: editorFocusToken,
                    onTextChange: handleEditorTextChange,
                    onPlaceholderVisibilityChange: handlePlaceholderVisibilityChange,
                    onSelectionLocationChange: { location in
                        onSelectionLocationChange(location)
                    },
                    onResolve: { textView in
                        if activeTextView !== textView {
                            activeTextView = textView
                        }
                    }
                )

                if isPlaceholderVisible {
                    Text("写点什么...")
                        .font(.system(size: EditorTextMetrics.fontSize, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, EditorTextMetrics.horizontalInset)
                        .padding(.top, EditorTextMetrics.verticalInset)
                        .padding(.bottom, EditorTextMetrics.verticalInset)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var tagPill: some View {
        Button {
            tagPickerPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(note?.tag?.color ?? Color.secondary.opacity(0.45))
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    }
                    .frame(width: 7, height: 7)

                Text(note?.tag?.title ?? "标签")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: FloatingChromeMetrics.pillHeight)
            .floatingCapsuleChrome(
                visualTheme: settings.visualTheme,
                colorScheme: colorScheme
            )
        }
        .buttonStyle(.plain)
        .disabled(note == nil)
        .help("设置标签")
        .popover(isPresented: $tagPickerPresented, arrowEdge: .bottom) {
            TagPickerPopover(selectedTag: note?.tag) { tag in
                store.updateSelectedTag(tag)
                tagPickerPresented = false
            }
        }
    }

    @ViewBuilder
    private var formatPill: some View {
        if isMarkdownMode {
            Button {
                toggleMarkdownPreview()
            } label: {
                formatPillLabel
            }
            .buttonStyle(.plain)
            .help(markdownPreviewEnabled ? "切换到编辑" : "切换到预览")
        } else {
            formatPillLabel
                .allowsHitTesting(false)
        }
    }

    private var formatPillLabel: some View {
        Text(formatLabel)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: FloatingChromeMetrics.pillHeight)
            .floatingCapsuleChrome(
                visualTheme: settings.visualTheme,
                colorScheme: colorScheme
            )
    }

    @ViewBuilder
    private var statusPill: some View {
        if let note {
            HStack(spacing: 7) {
                Text("\(note.characterCount) 字")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Rectangle()
                    .fill(.primary.opacity(0.16))
                    .frame(width: 1, height: 10)

                Text(note.updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: FloatingChromeMetrics.pillHeight)
            .floatingCapsuleChrome(
                visualTheme: settings.visualTheme,
                colorScheme: colorScheme
            )
            .allowsHitTesting(false)
        }
    }

    private var shouldDisplayMarkdownToolbar: Bool {
        settings.markdownToolbarEnabled
            && isMarkdownMode
            && !markdownPreviewEnabled
            && markdownToolbarVisible
    }

    private var isTopToolbarVisible: Bool {
        shouldDisplayMarkdownToolbar && settings.markdownToolbarPosition == .top
    }

    private var isBottomToolbarVisible: Bool {
        shouldDisplayMarkdownToolbar && settings.markdownToolbarPosition == .bottom
    }

    private var bottomFloatingChromeHeight: CGFloat {
        isBottomToolbarVisible
            ? FloatingChromeMetrics.bottomToolbarHeight
            : FloatingChromeMetrics.bottomStatusHeight
    }

    private var markdownToolbarPanel: some View {
        VStack(spacing: 6) {
            ForEach(MarkdownFormattingAction.rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 5) {
                    ForEach(MarkdownFormattingAction.rows[rowIndex]) { action in
                        MarkdownToolbarActionButton(action: action) {
                            applyMarkdownFormatting(action)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .frame(height: FloatingChromeMetrics.toolbarPanelHeight)
        .background {
            toolbarChromeBackground
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(chromeBorderColor, lineWidth: 1)
        }
        .shadow(color: chromeShadowColor, radius: 9, y: 3)
    }

    private func applyMarkdownFormatting(_ action: MarkdownFormattingAction) {
        guard isMarkdownMode else {
            return
        }

        if markdownPreviewEnabled {
            setMarkdownPreviewEnabled(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                applyMarkdownFormatting(action)
            }
            return
        }

        if let activeTextView,
           activeTextView.window != nil {
            action.apply(to: activeTextView)
            handleEditorTextChange(activeTextView.string)
            focusEditor()
            return
        }

        let updatedText = action.applying(to: currentEditorText())
        previewText = updatedText
        store.updateSelectedText(updatedText)
        focusEditor()
    }

    private func toggleMarkdownPreview() {
        setMarkdownPreviewEnabled(!markdownPreviewEnabled)
    }

    private func setMarkdownPreviewEnabled(_ enabled: Bool) {
        guard enabled != markdownPreviewEnabled else {
            return
        }

        if enabled {
            let text = currentEditorText()
            previewText = text
            store.updateSelectedText(text, publishImmediately: true)
            markdownToolbarVisibleBeforePreview = markdownToolbarVisible
            markdownToolbarVisible = false
            markdownPreviewEnabled = true
        } else {
            markdownPreviewEnabled = false
            markdownToolbarVisible = markdownToolbarVisibleBeforePreview
            focusEditor()
        }
    }

    private func toggleMarkdownTask(at sourceLine: Int) {
        guard isMarkdownMode else {
            return
        }

        var lines = previewText.components(separatedBy: .newlines)
        guard lines.indices.contains(sourceLine),
              let toggledLine = toggledTaskLine(lines[sourceLine])
        else {
            return
        }

        lines[sourceLine] = toggledLine
        let updatedText = lines.joined(separator: "\n")
        previewText = updatedText
        store.updateSelectedText(updatedText, publishImmediately: true)
    }

    private func handleEditorTextChange(_ text: String) {
        store.updateSelectedText(text)
    }

    private func handlePlaceholderVisibilityChange(_ isVisible: Bool) {
        if isPlaceholderVisible != isVisible {
            isPlaceholderVisible = isVisible
        }
    }

    private func currentEditorText() -> String {
        if markdownPreviewEnabled {
            return previewText
        }

        if let activeTextView,
           activeTextView.window != nil {
            return activeTextView.string
        }

        return store.selectedText
    }

    private func syncEditorSnapshotFromStore() {
        let text = store.selectedText
        previewText = text
        isPlaceholderVisible = text.isEmpty
    }

    private func navigateToOutlineTarget(_ target: NoteOutlineNavigationTarget?) {
        guard let target else {
            return
        }

        if markdownPreviewEnabled {
            setMarkdownPreviewEnabled(false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            scrollEditor(to: target.location)
        }
    }

    private func scrollEditor(to location: Int, retryCount: Int = 0) {
        guard let activeTextView,
              activeTextView.window != nil
        else {
            guard retryCount < 3 else {
                return
            }

            focusEditor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                scrollEditor(to: location, retryCount: retryCount + 1)
            }
            return
        }

        let text = activeTextView.string as NSString
        guard text.length > 0 else {
            return
        }

        let clampedLocation = min(max(location, 0), text.length - 1)
        let lineRange = text.lineRange(for: NSRange(location: clampedLocation, length: 0))
        activeTextView.window?.makeFirstResponder(activeTextView)
        activeTextView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
        onSelectionLocationChange(lineRange.location)
        activeTextView.scrollRangeToVisible(lineRange)
    }

    private func toggledTaskLine(_ line: String) -> String? {
        let indentation = String(line.prefix { character in
            character == " " || character == "\t"
        })
        let body = String(line.dropFirst(indentation.count))
        let uncheckedPrefix = "- [ ] "
        let checkedPrefixes = ["- [x] ", "- [X] "]

        if body.hasPrefix(uncheckedPrefix) {
            return indentation + "- [x] " + String(body.dropFirst(uncheckedPrefix.count))
        }

        for prefix in checkedPrefixes where body.hasPrefix(prefix) {
            return indentation + "- [ ] " + String(body.dropFirst(prefix.count))
        }

        return nil
    }

    private func focusEditor() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            editorFocusToken += 1
            if let activeTextView {
                activeTextView.window?.makeFirstResponder(activeTextView)
            }
        }
    }

    private var isMarkdownMode: Bool {
        settings.noteFormat == .markdown || note?.format == .markdown
    }
}

private struct EditorMoreMenuPopover: View {
    let canDeleteNote: Bool
    let onDeleteNote: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button(role: .destructive) {
                onDeleteNote()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 12.5, weight: .regular))

                    Text("删除当前笔记")
                        .font(.system(size: 12.5, weight: .medium))

                    Spacer(minLength: 0)
                }
                .foregroundStyle(canDeleteNote ? Color.red : Color.secondary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canDeleteNote)
        }
        .padding(6)
        .frame(width: 158)
    }
}

private struct TagPickerPopover: View {
    let selectedTag: NoteTag?
    let onSelect: (NoteTag?) -> Void

    var body: some View {
        VStack(spacing: 4) {
            TagPickerRow(
                title: "无标签",
                color: .secondary.opacity(0.55),
                isSelected: selectedTag == nil
            ) {
                onSelect(nil)
            }

            Divider()
                .padding(.vertical, 2)

            ForEach(NoteTag.allCases) { tag in
                TagPickerRow(
                    title: tag.title,
                    color: tag.color,
                    isSelected: selectedTag == tag
                ) {
                    onSelect(tag)
                }
            }
        }
        .padding(8)
        .frame(width: 154)
    }
}

private struct TagPickerRow: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Circle()
                    .fill(color)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    }
                    .frame(width: 10, height: 10)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.075) : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MarkdownToolbarActionButton: View {
    let action: MarkdownFormattingAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(action.shortTitle)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: 24)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.055))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(.primary.opacity(0.06), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .help(action.help)
    }
}

private enum FloatingChromeMetrics {
    static let horizontalPadding: CGFloat = 14
    static let topToolbarTopPadding: CGFloat = 12
    static let topToolbarBottomPadding: CGFloat = 8
    static let bottomTopPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 14
    static let toolbarPanelHeight: CGFloat = 70
    static let pillHeight: CGFloat = 28
    static let controlSpacing: CGFloat = 8

    static let bottomStatusHeight = pillHeight
        + bottomTopPadding
        + bottomPadding

    static let bottomToolbarHeight = toolbarPanelHeight
        + controlSpacing
        + pillHeight
        + bottomTopPadding
        + bottomPadding
}

private enum EditorTextMetrics {
    static let fontSize: CGFloat = 13.5
    static let horizontalInset: CGFloat = 20
    static let verticalInset: CGFloat = 14
    static let lineSpacing: CGFloat = 3
}

private struct MarkdownTextEditor: NSViewRepresentable {
    let noteID: UUID?
    let text: String
    let focusToken: Int
    let onTextChange: (String) -> Void
    let onPlaceholderVisibilityChange: (Bool) -> Void
    let onSelectionLocationChange: (Int) -> Void
    let onResolve: (NSTextView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(
            width: EditorTextMetrics.horizontalInset,
            height: EditorTextMetrics.verticalInset
        )
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.lineFragmentPadding = 0
        configure(textView)
        context.coordinator.representedNoteID = noteID

        scrollView.documentView = textView

        DispatchQueue.main.async {
            onPlaceholderVisibilityChange(isPlaceholderVisible(for: textView))
            onSelectionLocationChange(textView.selectedRange().location)
            onResolve(textView)
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self

        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        configure(textView)

        if context.coordinator.representedNoteID != noteID {
            context.coordinator.representedNoteID = noteID
            context.coordinator.isApplyingRepresentedText = true
            textView.string = text
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            context.coordinator.isApplyingRepresentedText = false
            onPlaceholderVisibilityChange(isPlaceholderVisible(for: textView))
            onSelectionLocationChange(textView.selectedRange().location)
        }

        onResolve(textView)

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func configure(_ textView: NSTextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = EditorTextMetrics.lineSpacing

        textView.font = .monospacedSystemFont(ofSize: EditorTextMetrics.fontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: EditorTextMetrics.fontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func isPlaceholderVisible(for textView: NSTextView) -> Bool {
        textView.string.isEmpty && !textView.hasMarkedText()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        var lastFocusToken: Int?
        var representedNoteID: UUID?
        var isApplyingRepresentedText = false

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            parent.onPlaceholderVisibilityChange(false)
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !isApplyingRepresentedText
            else {
                return
            }

            parent.onTextChange(textView.string)
            parent.onPlaceholderVisibilityChange(parent.isPlaceholderVisible(for: textView))
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.onPlaceholderVisibilityChange(parent.isPlaceholderVisible(for: textView))
            parent.onSelectionLocationChange(textView.selectedRange().location)
        }
    }
}

private enum LegacyMarkdownFormattingAction: String, CaseIterable, Identifiable {
    case body
    case heading1
    case heading2
    case heading3
    case bold
    case italic
    case bulletList
    case numberedList
    case quote
    case inlineCode
    case codeBlock
    case table

    var id: String {
        rawValue
    }

    static let rows: [[MarkdownFormattingAction]] = [
        [.body, .heading1, .heading2, .heading3, .bold, .italic],
        [.bulletList, .numberedList, .quote, .inlineCode, .codeBlock, .table]
    ]

    var shortTitle: String {
        switch self {
        case .body:
            return "正文"
        case .heading1:
            return "H1"
        case .heading2:
            return "H2"
        case .heading3:
            return "H3"
        case .bold:
            return "B"
        case .italic:
            return "I"
        case .bulletList:
            return "•"
        case .numberedList:
            return "1."
        case .quote:
            return ">"
        case .inlineCode:
            return "`"
        case .codeBlock:
            return "{}"
        case .table:
            return "表"
        }
    }

    var help: String {
        switch self {
        case .body:
            return "正文"
        case .heading1:
            return "一级标题"
        case .heading2:
            return "二级标题"
        case .heading3:
            return "三级标题"
        case .bold:
            return "加粗"
        case .italic:
            return "斜体"
        case .bulletList:
            return "无序列表"
        case .numberedList:
            return "有序列表"
        case .quote:
            return "引用"
        case .inlineCode:
            return "行内代码"
        case .codeBlock:
            return "代码块"
        case .table:
            return "表格"
        }
    }

    func apply(to textView: NSTextView) {
        switch self {
        case .body:
            applyLineStyle(to: textView, prefix: nil)
        case .heading1:
            applyLineStyle(to: textView, prefix: "# ")
        case .heading2:
            applyLineStyle(to: textView, prefix: "## ")
        case .heading3:
            applyLineStyle(to: textView, prefix: "### ")
        case .bold:
            wrapSelection(in: textView, prefix: "**", suffix: "**", placeholder: "加粗文字")
        case .italic:
            wrapSelection(in: textView, prefix: "*", suffix: "*", placeholder: "斜体文字")
        case .bulletList:
            applyLineStyle(to: textView, prefix: "- ")
        case .numberedList:
            applyNumberedList(to: textView)
        case .quote:
            applyLineStyle(to: textView, prefix: "> ")
        case .inlineCode:
            wrapSelection(in: textView, prefix: "`", suffix: "`", placeholder: "代码")
        case .codeBlock:
            insertBlock(in: textView, body: "代码", leading: "```\n", trailing: "\n```")
        case .table:
            insertTemplate(
                in: textView,
                template: "| 列一 | 列二 |\n| --- | --- |\n| 内容 | 内容 |"
            )
        }
    }

    func applying(to text: String) -> String {
        let separator = text.isEmpty || text.hasSuffix("\n") ? "" : "\n"
        return text + separator + fallbackTemplate
    }

    private var fallbackTemplate: String {
        switch self {
        case .body:
            return "正文"
        case .heading1:
            return "# 一级标题"
        case .heading2:
            return "## 二级标题"
        case .heading3:
            return "### 三级标题"
        case .bold:
            return "**加粗文字**"
        case .italic:
            return "*斜体文字*"
        case .bulletList:
            return "- 列表项"
        case .numberedList:
            return "1. 列表项"
        case .quote:
            return "> 引用"
        case .inlineCode:
            return "`代码`"
        case .codeBlock:
            return "```\n代码\n```"
        case .table:
            return "| 列一 | 列二 |\n| --- | --- |\n| 内容 | 内容 |"
        }
    }

    private func applyLineStyle(to textView: NSTextView, prefix: String?) {
        let nsString = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let lineRange = nsString.lineRange(for: selectedRange)
        let original = nsString.substring(with: lineRange)
        let hasTrailingNewline = original.hasSuffix("\n")
        var lines = original.components(separatedBy: "\n")

        if hasTrailingNewline {
            lines.removeLast()
        }

        let transformed = lines
            .map { line -> String in
                let stripped = stripLeadingMarkdownMarker(from: line)

                guard let prefix,
                      !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return stripped
                }

                return prefix + stripped
            }
            .joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")

        replace(
            in: textView,
            range: lineRange,
            with: transformed,
            selectedRange: NSRange(location: lineRange.location, length: (transformed as NSString).length)
        )
    }

    private func applyNumberedList(to textView: NSTextView) {
        let nsString = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let lineRange = nsString.lineRange(for: selectedRange)
        let original = nsString.substring(with: lineRange)
        let hasTrailingNewline = original.hasSuffix("\n")
        var lines = original.components(separatedBy: "\n")

        if hasTrailingNewline {
            lines.removeLast()
        }

        let transformed = lines.enumerated()
            .map { index, line -> String in
                let stripped = stripLeadingMarkdownMarker(from: line)

                guard !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return stripped
                }

                return "\(index + 1). \(stripped)"
            }
            .joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")

        replace(
            in: textView,
            range: lineRange,
            with: transformed,
            selectedRange: NSRange(location: lineRange.location, length: (transformed as NSString).length)
        )
    }

    private func wrapSelection(
        in textView: NSTextView,
        prefix: String,
        suffix: String,
        placeholder: String
    ) {
        let nsString = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let selectedText = nsString.substring(with: selectedRange)
        let inner = selectedText.isEmpty ? placeholder : selectedText
        let replacement = prefix + inner + suffix
        let innerLocation = selectedRange.location + (prefix as NSString).length

        replace(
            in: textView,
            range: selectedRange,
            with: replacement,
            selectedRange: NSRange(location: innerLocation, length: (inner as NSString).length)
        )
    }

    private func insertBlock(
        in textView: NSTextView,
        body: String,
        leading: String,
        trailing: String
    ) {
        let nsString = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let selectedText = nsString.substring(with: selectedRange)
        let inner = selectedText.isEmpty ? body : selectedText
        let before = needsLeadingNewline(in: nsString, at: selectedRange.location) ? "\n" : ""
        let after = needsTrailingNewline(in: nsString, after: selectedRange.location + selectedRange.length) ? "\n" : ""
        let replacement = before + leading + inner + trailing + after
        let innerLocation = selectedRange.location + (before + leading as NSString).length

        replace(
            in: textView,
            range: selectedRange,
            with: replacement,
            selectedRange: NSRange(location: innerLocation, length: (inner as NSString).length)
        )
    }

    private func insertTemplate(in textView: NSTextView, template: String) {
        let nsString = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let before = needsLeadingNewline(in: nsString, at: selectedRange.location) ? "\n" : ""
        let after = needsTrailingNewline(in: nsString, after: selectedRange.location + selectedRange.length) ? "\n" : ""
        let replacement = before + template + after

        replace(
            in: textView,
            range: selectedRange,
            with: replacement,
            selectedRange: NSRange(location: selectedRange.location, length: (replacement as NSString).length)
        )
    }

    private func stripLeadingMarkdownMarker(from line: String) -> String {
        var trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("#") {
            while trimmed.hasPrefix("#") {
                trimmed.removeFirst()
            }
            return trimmed.trimmingCharacters(in: .whitespaces)
        }

        for marker in ["- ", "* ", "+ ", "> "] where trimmed.hasPrefix(marker) {
            return String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }

        if let range = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            return String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        return trimmed
    }

    private func replace(
        in textView: NSTextView,
        range: NSRange,
        with replacement: String,
        selectedRange: NSRange
    ) {
        guard textView.shouldChangeText(in: range, replacementString: replacement) else {
            return
        }

        textView.textStorage?.replaceCharacters(in: range, with: replacement)
        textView.didChangeText()
        textView.setSelectedRange(selectedRange)
        textView.scrollRangeToVisible(selectedRange)
    }

    private func needsLeadingNewline(in string: NSString, at location: Int) -> Bool {
        guard location > 0 else {
            return false
        }

        return string.substring(with: NSRange(location: location - 1, length: 1)) != "\n"
    }

    private func needsTrailingNewline(in string: NSString, after location: Int) -> Bool {
        guard location < string.length else {
            return false
        }

        return string.substring(with: NSRange(location: location, length: 1)) != "\n"
    }
}
