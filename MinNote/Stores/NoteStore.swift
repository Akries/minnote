import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [PlainNote] = []
    @Published var selectedNoteID: UUID?

    private let fileManager: FileManager
    private let legacyNotesDirectory: URL
    private let settings: AppSettings
    private let metadataFileName = ".floatnote-meta.json"
    private let saveQueue = DispatchQueue(label: "dev.local.MinNote.note-writes", qos: .utility)
    private var noteTagsByFilename: [String: NoteTag] = [:]
    private var draftTextByNoteID: [UUID: String] = [:]
    private var draftUpdatedAtByNoteID: [UUID: Date] = [:]
    private var draftFormatByNoteID: [UUID: NoteFormat] = [:]
    private var pendingDraftMetadataPublishWorkItem: DispatchWorkItem?
    private let draftMetadataPublishDelay: TimeInterval = 0.16

    init(settings: AppSettings, fileManager: FileManager = .default) {
        self.settings = settings
        self.fileManager = fileManager
        self.legacyNotesDirectory = Self.legacyNotesDirectory(fileManager: fileManager)
        loadNotes()
    }

    var storageDirectory: URL {
        settings.storageDirectoryURL
    }

    var selectedNote: PlainNote? {
        guard let selectedNoteID else {
            return nil
        }

        return notes.first(where: { $0.id == selectedNoteID })
    }

    var selectedText: String {
        guard let selectedNoteID else {
            return ""
        }

        if let draftText = draftTextByNoteID[selectedNoteID] {
            return draftText
        }

        return notes.first(where: { $0.id == selectedNoteID })?.text ?? ""
    }

    func createNote(initialText: String = "") {
        flushPendingSave()

        let now = Date()
        var note = PlainNote(
            id: UUID(),
            text: initialText,
            createdAt: now,
            updatedAt: now,
            fileURL: nil,
            format: settings.noteFormat,
            tag: nil
        )
        note = save(note)
        notes.insert(note, at: 0)
        selectedNoteID = note.id
    }

    func select(_ note: PlainNote) {
        flushPendingSave()
        selectedNoteID = note.id
    }

    func updateSelectedText(_ text: String, publishImmediately: Bool = false) {
        guard let selectedNoteID,
              let index = notes.firstIndex(where: { $0.id == selectedNoteID })
        else {
            return
        }

        let targetFormat = settings.noteFormat
        let currentText = draftTextByNoteID[selectedNoteID] ?? notes[index].text
        let currentFormat = draftFormatByNoteID[selectedNoteID] ?? notes[index].format

        if currentText == text, currentFormat == targetFormat {
            if publishImmediately {
                flushPendingSave()
            }
            return
        }

        let updatedAt = Date()
        draftTextByNoteID[selectedNoteID] = text
        draftUpdatedAtByNoteID[selectedNoteID] = updatedAt
        draftFormatByNoteID[selectedNoteID] = targetFormat
        enqueueRealtimeWrite(text, to: realtimeWriteURL(for: notes[index], format: targetFormat))

        if publishImmediately {
            cancelPendingDraftMetadataPublish()
            publishDraftMetadata(
                noteID: selectedNoteID,
                text: text,
                updatedAt: updatedAt,
                format: targetFormat
            )
            flushPendingSave()
        } else {
            scheduleDraftMetadataPublish(
                noteID: selectedNoteID,
                text: text,
                updatedAt: updatedAt,
                format: targetFormat
            )
        }
    }

    func updateSelectedTag(_ tag: NoteTag?) {
        flushPendingSave()

        guard let selectedNoteID,
              let index = notes.firstIndex(where: { $0.id == selectedNoteID })
        else {
            return
        }

        objectWillChange.send()
        notes[index].tag = tag
        updateTagMetadata(for: notes[index])
    }

    func deleteSelectedNote() {
        guard let selectedNoteID else {
            return
        }

        flushPendingSave()

        guard let index = notes.firstIndex(where: { $0.id == selectedNoteID }) else {
            return
        }

        let note = notes[index]
        if let fileURL = note.fileURL {
            do {
                try moveFileToTrash(fileURL)
            } catch {
                NSLog("MinNote trash note failed: \(error.localizedDescription)")
                return
            }

            removeTagMetadata(for: fileURL.lastPathComponent)
        }

        notes.remove(at: index)

        if notes.isEmpty {
            createNote()
        } else {
            self.selectedNoteID = notes[min(index, notes.count - 1)].id
        }
    }

    func selectNext() {
        flushPendingSave()
        moveSelection(offset: 1)
    }

    func selectPrevious() {
        flushPendingSave()
        moveSelection(offset: -1)
    }

    func reloadFromStorage() {
        flushPendingSave()
        loadNotes()
    }

    func flushPendingSave() {
        cancelPendingDraftMetadataPublish()
        saveQueue.sync {}
        commitDraftsToPublishedNotes(shouldSort: true)
    }

    private func enqueueRealtimeWrite(_ text: String, to url: URL) {
        saveQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSLog("MinNote realtime save failed: \(error.localizedDescription)")
            }
        }
    }

    private func realtimeWriteURL(for note: PlainNote, format: NoteFormat) -> URL {
        if let fileURL = note.fileURL {
            return fileURL
        }

        var note = note
        note.format = format
        return fileURL(for: note)
    }

    private func commitDraftsToPublishedNotes(shouldSort: Bool) {
        guard !draftTextByNoteID.isEmpty else {
            return
        }

        let currentSelection = selectedNoteID
        let drafts = draftTextByNoteID
        let updatedAtByID = draftUpdatedAtByNoteID
        let formatByID = draftFormatByNoteID
        draftTextByNoteID.removeAll()
        draftUpdatedAtByNoteID.removeAll()
        draftFormatByNoteID.removeAll()

        for (noteID, text) in drafts {
            guard let index = notes.firstIndex(where: { $0.id == noteID }) else {
                continue
            }

            notes[index].text = text
            notes[index].updatedAt = updatedAtByID[noteID] ?? Date()
            notes[index].format = formatByID[noteID] ?? notes[index].format
            notes[index] = save(notes[index])
        }

        if shouldSort {
            notes.sort { $0.updatedAt > $1.updatedAt }
            selectedNoteID = currentSelection
        }
    }

    private func scheduleDraftMetadataPublish(
        noteID: UUID,
        text: String,
        updatedAt: Date,
        format: NoteFormat
    ) {
        cancelPendingDraftMetadataPublish()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.pendingDraftMetadataPublishWorkItem = nil
                self.publishDraftMetadata(
                    noteID: noteID,
                    text: text,
                    updatedAt: updatedAt,
                    format: format
                )
            }
        }

        pendingDraftMetadataPublishWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + draftMetadataPublishDelay,
            execute: workItem
        )
    }

    private func cancelPendingDraftMetadataPublish() {
        pendingDraftMetadataPublishWorkItem?.cancel()
        pendingDraftMetadataPublishWorkItem = nil
    }

    private func publishDraftMetadata(
        noteID: UUID,
        text: String,
        updatedAt: Date,
        format: NoteFormat
    ) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else {
            return
        }

        let currentSelection = selectedNoteID
        objectWillChange.send()
        notes[index].text = text
        notes[index].updatedAt = updatedAt
        notes[index].format = format
        notes.sort { $0.updatedAt > $1.updatedAt }
        selectedNoteID = currentSelection
    }

    private func loadNotes() {
        do {
            try fileManager.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true
            )
            migrateLegacyNotesIfNeeded()
            loadTagMetadata()

            let noteFiles = try fileManager.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            .filter { NoteFormat.from(fileExtension: $0.pathExtension) != nil }

            notes = noteFiles.compactMap(loadNote)
                .sorted { $0.updatedAt > $1.updatedAt }
            pruneTagMetadata(keeping: Set(notes.compactMap { $0.fileURL?.lastPathComponent }))

            if notes.isEmpty {
                createNote()
            } else {
                selectedNoteID = notes.first?.id
            }
        } catch {
            notes = []
            createNote()
        }
    }

    private func loadNote(from url: URL) -> PlainNote? {
        guard let format = NoteFormat.from(fileExtension: url.pathExtension) else {
            return nil
        }

        let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID()
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let now = Date()

        return PlainNote(
            id: id,
            text: text,
            createdAt: values?.creationDate ?? now,
            updatedAt: values?.contentModificationDate ?? now,
            fileURL: url,
            format: format,
            tag: noteTagsByFilename[url.lastPathComponent]
        )
    }

    @discardableResult
    private func save(_ note: PlainNote) -> PlainNote {
        var note = note

        do {
            try fileManager.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true
            )

            let destination = fileURL(for: note)
            let previousFilename = note.fileURL?.lastPathComponent
            try note.text.write(to: destination, atomically: true, encoding: .utf8)

            if let previousURL = note.fileURL,
               previousURL.standardizedFileURL.path != destination.standardizedFileURL.path {
                try? fileManager.removeItem(at: previousURL)
            }

            note.fileURL = destination
            updateTagMetadata(for: note, previousFilename: previousFilename)
        } catch {
            NSLog("MinNote save failed: \(error.localizedDescription)")
        }

        return note
    }

    private func migrateLegacyNotesIfNeeded() {
        guard fileManager.fileExists(atPath: legacyNotesDirectory.path),
              ((try? fileManager.contentsOfDirectory(atPath: storageDirectory.path).isEmpty) ?? true)
        else {
            return
        }

        guard let legacyFiles = try? fileManager.contentsOfDirectory(
            at: legacyNotesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in legacyFiles where NoteFormat.from(fileExtension: fileURL.pathExtension) != nil {
            let destination = storageDirectory.appendingPathComponent(fileURL.lastPathComponent)
            try? fileManager.copyItem(at: fileURL, to: destination)
        }
    }

    private func moveSelection(offset: Int) {
        guard !notes.isEmpty else {
            return
        }

        guard let selectedNoteID,
              let currentIndex = notes.firstIndex(where: { $0.id == selectedNoteID })
        else {
            self.selectedNoteID = notes.first?.id
            return
        }

        let nextIndex = (currentIndex + offset + notes.count) % notes.count
        self.selectedNoteID = notes[nextIndex].id
    }

    private func moveFileToTrash(_ fileURL: URL) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        var trashedURL: NSURL?
        try fileManager.trashItem(at: fileURL, resultingItemURL: &trashedURL)
    }

    private func fileURL(for note: PlainNote) -> URL {
        let ext = note.format.fileExtension
        let baseName = sanitizedBaseName(for: note, fileExtension: ext)
        let candidate = storageDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension(ext)

        guard shouldUse(candidate, for: note.fileURL) else {
            return uniqueFileURL(baseName: baseName, ext: ext, excluding: note.fileURL)
        }

        return candidate
    }

    private func sanitizedBaseName(for note: PlainNote, fileExtension: String) -> String {
        if let filenameTitle = note.filenameTitle {
            return sanitize(filenameTitle)
        }

        if let existingName = note.fileURL?.deletingPathExtension().lastPathComponent,
           existingName.hasPrefix("空白笔记") {
            return existingName
        }

        return nextBlankBaseName(excluding: note.fileURL, fileExtension: fileExtension)
    }

    private func nextBlankBaseName(excluding excludedURL: URL?, fileExtension: String) -> String {
        var index = 1

        while true {
            let baseName = "空白笔记\(index)"
            let url = storageDirectory
                .appendingPathComponent(baseName)
                .appendingPathExtension(fileExtension)

            if shouldUse(url, for: excludedURL) {
                return baseName
            }

            index += 1
        }
    }

    private func uniqueFileURL(baseName: String, ext: String, excluding excludedURL: URL?) -> URL {
        var index = 2

        while true {
            let url = storageDirectory
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension(ext)

            if shouldUse(url, for: excludedURL) {
                return url
            }

            index += 1
        }
    }

    private func shouldUse(_ url: URL, for excludedURL: URL?) -> Bool {
        if let excludedURL,
           excludedURL.standardizedFileURL.path == url.standardizedFileURL.path {
            return true
        }

        return !fileManager.fileExists(atPath: url.path)
    }

    private var metadataURL: URL {
        storageDirectory.appendingPathComponent(metadataFileName)
    }

    private func loadTagMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([String: NoteTag].self, from: data)
        else {
            noteTagsByFilename = [:]
            return
        }

        noteTagsByFilename = decoded
    }

    private func updateTagMetadata(for note: PlainNote, previousFilename: String? = nil) {
        guard let filename = note.fileURL?.lastPathComponent else {
            return
        }

        var updated = false

        if let previousFilename,
           previousFilename != filename,
           noteTagsByFilename.removeValue(forKey: previousFilename) != nil {
            updated = true
        }

        if let tag = note.tag {
            if noteTagsByFilename[filename] != tag {
                noteTagsByFilename[filename] = tag
                updated = true
            }
        } else if noteTagsByFilename.removeValue(forKey: filename) != nil {
            updated = true
        }

        if updated {
            saveTagMetadata()
        }
    }

    private func removeTagMetadata(for filename: String) {
        guard noteTagsByFilename.removeValue(forKey: filename) != nil else {
            return
        }

        saveTagMetadata()
    }

    private func pruneTagMetadata(keeping filenames: Set<String>) {
        let pruned = noteTagsByFilename.filter { filenames.contains($0.key) }
        guard pruned != noteTagsByFilename else {
            return
        }

        noteTagsByFilename = pruned
        saveTagMetadata()
    }

    private func saveTagMetadata() {
        do {
            try fileManager.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true
            )

            if noteTagsByFilename.isEmpty {
                try? fileManager.removeItem(at: metadataURL)
                return
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(noteTagsByFilename)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            NSLog("MinNote metadata save failed: \(error.localizedDescription)")
        }
    }

    private func sanitize(_ name: String) -> String {
        let illegalCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)

        let sanitized = name
            .components(separatedBy: illegalCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? "空白笔记" : String(sanitized.prefix(80))
    }

    private static func legacyNotesDirectory(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("MinNote", isDirectory: true)
            .appendingPathComponent("Notes", isDirectory: true)
    }
}
