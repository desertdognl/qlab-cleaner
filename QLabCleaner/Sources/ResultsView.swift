import SwiftUI
import AppKit
import Quartz

enum Clipboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct ResultsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var loc: Localization
    @State private var search = ""
    @State private var sort: FileSort = .name
    @State private var selectedPath: String?
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if let analysis = store.analysis {
                totalsBar(analysis)
            }
            if store.isWorking {
                Notice(
                    text: store.progressKey.map { loc.t($0, store.progressCount) } ?? loc.t("workspace.reading"),
                    tone: .info
                )
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            if let qlab = store.qlabWarning {
                Notice(text: qlab, tone: store.qlabBlocksTrash ? .danger : .warning)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }
            if !store.folderWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.folderWarnings, id: \.self) { warning in
                        Notice(text: warning, tone: .warning)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            if let error = store.errorMessage {
                Notice(text: error, tone: .danger)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }
            HStack(alignment: .top, spacing: 14) {
                ResultColumn(
                    title: loc.t("results.used"),
                    count: filteredUsed.count,
                    accent: Theme.used,
                    emptyTitle: loc.t("results.usedEmpty"),
                    emptyBody: emptyUsedText,
                    files: filteredUsed,
                    groupByKind: sort.groupsByKind,
                    selectedPath: selectedPath,
                    onSelect: selectFile
                )
                ResultColumn(
                    title: loc.t("results.unused"),
                    count: filteredUnused.count,
                    accent: Theme.unused,
                    emptyTitle: loc.t("results.unusedEmpty"),
                    emptyBody: emptyUnusedText,
                    files: filteredUnused,
                    groupByKind: sort.groupsByKind,
                    selectedPath: selectedPath,
                    onSelect: selectFile,
                    trashEnabled: search.isEmpty && !(store.analysis?.unused.isEmpty ?? true) && !store.isWorking && !store.qlabBlocksTrash,
                    onTrash: store.trashUnused,
                    copyAllEnabled: search.isEmpty && !(store.analysis?.unused.isEmpty ?? true),
                    onCopyAll: copyUnusedPaths
                )
                MissingColumn(
                    title: loc.t("results.missing"),
                    count: filteredMissing.count,
                    files: filteredMissing,
                    emptyTitle: loc.t("results.missingEmpty"),
                    emptyBody: emptyMissingText,
                    groupByKind: sort.groupsByKind
                )
                if store.includeBackups {
                    MissingColumn(
                        title: loc.t("results.backupOnly"),
                        count: filteredBackupOnly.count,
                        files: filteredBackupOnly,
                        emptyTitle: emptyBackupTitle,
                        emptyBody: emptyBackupText,
                        groupByKind: sort.groupsByKind,
                        accent: Theme.accent
                    )
                }
            }
            .padding(20)
        }
        .onAppear(perform: startKeyMonitor)
        .onDisappear(perform: stopKeyMonitor)
    }

    private func selectFile(_ match: FileMatch) {
        selectedPath = match.file.url.path
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 49 else { return event }
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) {
                return event
            }
            if event.window?.firstResponder is NSTextView {
                return event
            }
            if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isVisible {
                return event
            }
            guard let selectedPath, FileManager.default.fileExists(atPath: selectedPath) else {
                return event
            }
            QuickLookSupport.shared.preview(url: URL(fileURLWithPath: selectedPath))
            return nil
        }
    }

    private func copyUnusedPaths() {
        let paths = (store.analysis?.unused ?? []).map(\.file.url.path).joined(separator: "\n")
        guard !paths.isEmpty else { return }
        Clipboard.copy(paths)
    }

    private func stopKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func totalsBar(_ analysis: AnalysisResult) -> some View {
        HStack(spacing: 10) {
            TotalChip(title: loc.t("results.totalScanned"), value: ByteFormat.string(analysis.scannedBytes), color: Theme.textMuted)
            TotalChip(title: loc.t("results.totalUsed"), value: ByteFormat.string(analysis.usedBytes), color: Theme.used)
            TotalChip(title: loc.t("results.totalUnused"), value: ByteFormat.string(analysis.unusedBytes), color: Theme.unused)
            if !analysis.protectedSkipped.isEmpty {
                TotalChip(title: loc.t("results.totalProtected"), value: ByteFormat.string(analysis.protectedBytes), color: Theme.textMuted)
            }
            if analysis.unusedDuplicateCount > 0 {
                TotalChip(title: loc.t("results.duplicates"), value: "\(analysis.unusedDuplicateCount)", color: Theme.unused)
            }
            if store.includeBackups {
                TotalChip(
                    title: loc.t("results.totalBackups"),
                    value: "\(analysis.backupFiles.count)",
                    color: Theme.accent
                )
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.bg)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                store.step = .configure
                store.analysis = nil
            } label: {
                Label(loc.t("results.back"), systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
            .buttonStyle(.plain)

            Button {
                store.reset()
            } label: {
                Text(loc.t("results.new"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
            .buttonStyle(.plain)

            Toggle(loc.t("results.ignoreDisarmed"), isOn: $store.ignoreDisarmed)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
                .onChange(of: store.ignoreDisarmed) { _ in
                    if store.analysis != nil { store.analyze() }
                }

            Toggle(loc.t("results.includeBackups"), isOn: $store.includeBackups)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
                .help(loc.t("results.includeBackupsHelp"))
                .onChange(of: store.includeBackups) { _ in
                    if store.analysis != nil { store.analyze() }
                }

            Spacer()

            Menu {
                ForEach(FileSort.allCases) { option in
                    Button(option.label) { sort = option }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text(sort.label)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.textFaint)
                }
                .foregroundColor(Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .themeControl(radius: 20)
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: 150)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textFaint)
                TextField(loc.t("results.search"), text: $search)
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 320)
            .themeControl(radius: 20)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Theme.bgElevated)
        .overlay(Divider().background(Theme.stroke), alignment: .bottom)
    }

    private var filteredUsed: [FileMatch] { sort.sorted(filter(store.analysis?.used ?? [])) }
    private var filteredUnused: [FileMatch] { sort.sorted(filter(store.analysis?.unused ?? [])) }

    private var filteredMissing: [ReferencedMedia] {
        let items = store.analysis?.missing ?? []
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [ReferencedMedia]
        if query.isEmpty {
            filtered = items
        } else {
            filtered = items.filter {
                $0.fileName.localizedCaseInsensitiveContains(query)
                    || $0.displayPath.localizedCaseInsensitiveContains(query)
                    || $0.cues.contains {
                        $0.label.localizedCaseInsensitiveContains(query)
                            || $0.number.localizedCaseInsensitiveContains(query)
                            || $0.name.localizedCaseInsensitiveContains(query)
                    }
            }
        }
        return sort.sortedMissing(filtered)
    }

    private var filteredBackupOnly: [ReferencedMedia] {
        let items = store.analysis?.backupOnly ?? []
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [ReferencedMedia]
        if query.isEmpty {
            filtered = items
        } else {
            filtered = items.filter {
                $0.fileName.localizedCaseInsensitiveContains(query)
                    || $0.displayPath.localizedCaseInsensitiveContains(query)
                    || $0.cues.contains {
                        $0.label.localizedCaseInsensitiveContains(query)
                            || $0.number.localizedCaseInsensitiveContains(query)
                            || $0.name.localizedCaseInsensitiveContains(query)
                    }
            }
        }
        return sort.sortedMissing(filtered)
    }

    private func filter(_ items: [FileMatch]) -> [FileMatch] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.file.fileName.localizedCaseInsensitiveContains(query)
                || $0.file.relativePath.localizedCaseInsensitiveContains(query)
                || $0.file.url.path.localizedCaseInsensitiveContains(query)
                || ($0.reference?.cues.contains { cue in
                    cue.label.localizedCaseInsensitiveContains(query)
                        || cue.number.localizedCaseInsensitiveContains(query)
                        || cue.name.localizedCaseInsensitiveContains(query)
                } ?? false)
        }
    }

    private var emptyUsedText: String {
        search.isEmpty ? loc.t("results.usedEmptyBody") : loc.t("results.usedNoHits")
    }

    private var emptyUnusedText: String {
        search.isEmpty ? loc.t("results.unusedEmptyBody") : loc.t("results.unusedNoHits")
    }

    private var emptyMissingText: String {
        search.isEmpty ? loc.t("results.missingEmptyBody") : loc.t("results.missingNoHits")
    }

    private var emptyBackupTitle: String {
        if !search.isEmpty { return loc.t("results.backupOnlyEmpty") }
        if (store.analysis?.backupFiles.isEmpty ?? true) {
            return loc.t("results.backupOnlyNone")
        }
        return loc.t("results.backupOnlyEmpty")
    }

    private var emptyBackupText: String {
        if !search.isEmpty { return loc.t("results.backupOnlyNoHits") }
        if (store.analysis?.backupFiles.isEmpty ?? true) {
            return loc.t("results.backupOnlyNoneBody")
        }
        return loc.t("results.backupOnlyEmptyBody")
    }
}

struct TotalChip: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textFaint)
                .tracking(0.6)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .themeControl()
    }
}

struct ResultColumn: View {
    let title: String
    let count: Int
    let accent: Color
    let emptyTitle: String
    let emptyBody: String
    let files: [FileMatch]
    var groupByKind: Bool = true
    var selectedPath: String? = nil
    var onSelect: ((FileMatch) -> Void)? = nil
    var trashEnabled: Bool = false
    var onTrash: (() -> Void)? = nil
    var copyAllEnabled: Bool = false
    var onCopyAll: (() -> Void)? = nil
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.14))
                    .cornerRadius(8)
            }
            .padding(14)
            .overlay(Divider().background(Theme.stroke), alignment: .bottom)

            if copyAllEnabled, let onCopyAll {
                Button(action: onCopyAll) {
                    Label(loc.t("results.copyAll"), systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Theme.surface)
                .overlay(Divider().background(Theme.stroke), alignment: .bottom)
            }

            if trashEnabled, let onTrash {
                Button(action: onTrash) {
                    Label(loc.t("results.trash"), systemImage: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.unused)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Theme.unusedSoft)
                .overlay(Divider().background(Theme.stroke), alignment: .bottom)
            }

            if files.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(emptyTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(emptyBody)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 240)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if groupByKind {
                            ForEach(FileGroups.grouped(files), id: \.0) { kind, items in
                                Text(kind.groupTitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.textFaint)
                                    .padding(.top, 4)
                                ForEach(items) { match in
                                    FileRow(
                                        match: match,
                                        isSelected: selectedPath == match.file.url.path,
                                        onSelect: { onSelect?(match) }
                                    )
                                }
                            }
                        } else {
                            ForEach(files) { match in
                                FileRow(
                                    match: match,
                                    isSelected: selectedPath == match.file.url.path,
                                    onSelect: { onSelect?(match) }
                                )
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themePanel()
    }
}

struct MissingColumn: View {
    let title: String
    let count: Int
    let files: [ReferencedMedia]
    let emptyTitle: String
    let emptyBody: String
    var groupByKind: Bool = true
    var accent: Color = Theme.danger

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.14))
                    .cornerRadius(8)
            }
            .padding(14)
            .overlay(Divider().background(Theme.stroke), alignment: .bottom)

            if files.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(emptyTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(emptyBody)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 240)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if groupByKind {
                            ForEach(FileGroups.groupedMissing(files), id: \.0) { kind, items in
                                Text(kind.groupTitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.textFaint)
                                    .padding(.top, 4)
                                ForEach(items) { item in
                                    MissingRow(item: item, accent: accent)
                                }
                            }
                        } else {
                            ForEach(files) { item in
                                MissingRow(item: item, accent: accent)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themePanel()
    }
}

struct FileRow: View {
    let match: FileMatch
    var isSelected = false
    var onSelect: (() -> Void)? = nil
    @EnvironmentObject private var loc: Localization
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(match.status == .used ? Theme.usedSoft : Theme.unusedSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: match.file.kind.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(match.status == .used ? Theme.used : Theme.unused)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(match.file.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(match.file.relativePath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let cues = match.reference?.cues, !cues.isEmpty {
                    Text(cues.map(\.label).joined(separator: "  ·  "))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(1)
                }
                if !match.duplicateNames.isEmpty {
                    Text(loc.t("results.duplicate", match.duplicateNames.joined(separator: ", ")))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.unused)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if match.status == .used, let count = match.reference?.usageCount {
                Text("\(count)×")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.used)
                    .help(loc.t("results.usageHelp"))
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([match.file.url])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(hovering ? Theme.text : Theme.textFaint)
            }
            .buttonStyle(.plain)
            .help(loc.t("results.reveal"))
        }
        .padding(8)
        .background(isSelected ? Theme.surfaceHover : (hovering ? Theme.surfaceHover : Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .stroke(isSelected ? Theme.strokeStrong : Color.clear, lineWidth: 1)
        )
        .cornerRadius(Theme.radiusSmall)
        .onHover { hovering = $0 }
        .onTapGesture {
            onSelect?()
        }
        .contextMenu {
            Button(loc.t("results.copyPath")) {
                Clipboard.copy(match.file.url.path)
            }
            Button(loc.t("results.reveal")) {
                NSWorkspace.shared.activateFileViewerSelecting([match.file.url])
            }
        }
        .help(loc.t("results.selectHelp"))
    }
}

struct MissingRow: View {
    let item: ReferencedMedia
    var accent: Color = Theme.danger
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: item.kind.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(item.displayPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !item.cues.isEmpty {
                    Text(item.cues.map(\.label).joined(separator: "  ·  "))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(item.usageCount)×")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(accent)
        }
        .padding(8)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusSmall)
        .contextMenu {
            Button(loc.t("results.copyPath")) {
                Clipboard.copy(item.displayPath)
            }
        }
    }
}
