import Foundation
import SwiftUI
import AppKit

enum AppStep {
    case chooseMode
    case configure
    case results
}

final class AppStore: ObservableObject {
    @Published var step: AppStep = .chooseMode
    @Published var mode: ProjectMode = .bundledCopy
    @Published var workspaceURL: URL?
    @Published var workspace: QLabWorkspace?
    @Published var contentFolders: [URL] = []
    @Published var bundledFolders: [URL] = []
    @Published var analysis: AnalysisResult?
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var modeMismatchWarning: String?
    @Published var folderWarnings: [String] = []
    @Published var workspaceCandidates: [URL] = []
    @Published var qlabWarning: String?
    @Published var qlabBlocksTrash = false
    @Published var protectedFolders: [URL] = []
    @Published var protectedExtensionsText = ""
    @Published var ignoreDisarmed = false
    @Published var includeBackups = false
    @Published var recents: [RecentWorkspace] = RecentsStore.load()
    @Published var progressKey: String?
    @Published var progressCount = 0
    @Published var showingAbout = false

    var suggestedMode: ProjectMode? {
        guard let copies = workspace?.copiesFilesIntoProject else { return nil }
        return copies ? .bundledCopy : .externalRefs
    }

    func applySuggestedMode() {
        guard let suggested = suggestedMode, suggested != mode else { return }
        mode = suggested
        if suggested == .externalRefs, contentFolders.isEmpty, let workspace {
            contentFolders = Analyzer.suggestedFolders(from: workspace)
        }
        updateMismatchWarning()
        refreshFolderWarnings()
        rememberCurrentWorkspace()
    }

    func selectMode(_ mode: ProjectMode) {
        self.mode = mode
        errorMessage = nil
        modeMismatchWarning = nil
        folderWarnings = []
        workspaceCandidates = []
        qlabWarning = nil
        qlabBlocksTrash = false
        protectedFolders = []
        step = .configure
    }

    func reset() {
        step = .chooseMode
        workspaceURL = nil
        workspace = nil
        contentFolders = []
        bundledFolders = []
        analysis = nil
        errorMessage = nil
        searchText = ""
        modeMismatchWarning = nil
        folderWarnings = []
        workspaceCandidates = []
        qlabWarning = nil
        qlabBlocksTrash = false
        protectedFolders = []
        ignoreDisarmed = false
        includeBackups = false
        isWorking = false
    }

    func loadWorkspace(from url: URL) {
        isWorking = true
        errorMessage = nil
        modeMismatchWarning = nil
        workspaceCandidates = []

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var workspaceURL = url
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                if isDirectory.boolValue {
                    let files = try QLabParser.findWorkspaceFiles(in: url)
                    if files.isEmpty { throw ParserError.noWorkspaceFile }
                    if files.count > 1 {
                        DispatchQueue.main.async {
                            self.workspaceCandidates = files
                            self.isWorking = false
                        }
                        return
                    }
                    workspaceURL = files[0]
                }

                let parsed = try QLabParser.parse(workspaceURL: workspaceURL)
                let bundled = try Analyzer.discoverBundledFolders(in: parsed.directory)
                let suggested = Analyzer.suggestedFolders(from: parsed)

                DispatchQueue.main.async {
                    self.workspaceURL = workspaceURL
                    self.workspace = parsed
                    self.bundledFolders = bundled
                    if self.mode == .externalRefs, self.contentFolders.isEmpty {
                        self.contentFolders = suggested
                    }
                    self.updateMismatchWarning()
                    self.refreshFolderWarnings()
                    self.refreshQLabLock()
                    self.rememberCurrentWorkspace()
                    self.isWorking = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isWorking = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func addContentFolders(_ urls: [URL]) {
        var existing = Set(contentFolders.map { $0.path.lowercased() })
        for url in urls {
            let standardized = url.standardizedFileURL
            if existing.insert(standardized.path.lowercased()).inserted {
                contentFolders.append(standardized)
            }
        }
        refreshFolderWarnings()
        rememberCurrentWorkspace()
    }

    func removeContentFolder(_ url: URL) {
        contentFolders.removeAll { $0.path.lowercased() == url.path.lowercased() }
        refreshFolderWarnings()
        rememberCurrentWorkspace()
    }

    func openRecent(_ recent: RecentWorkspace) {
        guard recent.isAvailable else {
            recents.removeAll { $0.id == recent.id }
            RecentsStore.save(recents)
            errorMessage = L10n.t("recents.missing")
            return
        }
        mode = recent.mode
        contentFolders = recent.contentFolderPaths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        errorMessage = nil
        modeMismatchWarning = nil
        folderWarnings = []
        workspaceCandidates = []
        qlabWarning = nil
        qlabBlocksTrash = false
        protectedFolders = []
        step = .configure
        loadWorkspace(from: recent.url)
    }

    func removeRecent(_ recent: RecentWorkspace) {
        recents.removeAll { $0.id == recent.id }
        RecentsStore.save(recents)
    }

    private func rememberCurrentWorkspace() {
        guard let workspaceURL else { return }
        let item = RecentWorkspace(
            workspacePath: workspaceURL.path,
            modeRaw: mode.rawValue,
            contentFolderPaths: contentFolders.map(\.path),
            openedAt: Date()
        )
        recents.removeAll { $0.id == item.id }
        recents.insert(item, at: 0)
        if recents.count > 8 {
            recents = Array(recents.prefix(8))
        }
        RecentsStore.save(recents)
    }

    func analyze() {
        guard let workspace else {
            errorMessage = L10n.t("workspace.needWorkspace")
            return
        }
        if mode == .externalRefs && contentFolders.isEmpty {
            errorMessage = L10n.t("workspace.needFolder")
            return
        }

        isWorking = true
        errorMessage = nil
        progressKey = nil
        progressCount = 0
        let capturedMode = self.mode
        let folders = contentFolders
        let protected = protectedFolders
        let extensionText = protectedExtensionsText
        let skipDisarmed = ignoreDisarmed
        let readBackups = includeBackups

        let throttle = ProgressThrottle()
        DispatchQueue.global(qos: .utility).async {
            do {
                let result = try Analyzer.analyze(
                    workspace: workspace,
                    mode: capturedMode,
                    extraFolders: folders,
                    protectedFolders: protected,
                    protectedExtensions: Self.extensions(from: extensionText),
                    ignoreDisarmed: skipDisarmed,
                    includeBackups: readBackups,
                    progress: { key, count in
                        throttle.update(key, count) { message, value in
                            self.progressKey = message
                            self.progressCount = value
                        }
                    }
                )
                DispatchQueue.main.async {
                    self.analysis = result
                    self.folderWarnings = result.warnings
                    self.refreshQLabLock()
                    self.progressKey = nil
                    self.isWorking = false
                    self.step = .results
                }
            } catch {
                DispatchQueue.main.async {
                    self.progressKey = nil
                    self.isWorking = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func trashUnused() {
        refreshQLabLock()
        if qlabBlocksTrash {
            errorMessage = qlabWarning ?? L10n.t("qlab.blocksTrash")
            return
        }
        guard let analysis, !analysis.unused.isEmpty else { return }
        let urls = analysis.unused.map(\.file.url)
        let alert = NSAlert()
        alert.messageText = urls.count == 1
            ? L10n.t("results.trashOne")
            : L10n.t("results.trashMany", urls.count)
        alert.informativeText = L10n.t("results.trashInfo", ByteFormat.string(analysis.unusedBytes))
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.t("results.trash"))
        alert.addButton(withTitle: L10n.t("results.cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        isWorking = true
        errorMessage = nil
        NSWorkspace.shared.recycle(urls) { _, error in
            DispatchQueue.main.async {
                if let error {
                    self.isWorking = false
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.analyze()
            }
        }
    }

    func toggleProtected(_ url: URL) {
        let key = url.standardizedFileURL.path.lowercased()
        if protectedFolders.contains(where: { $0.path.lowercased() == key }) {
            protectedFolders.removeAll { $0.path.lowercased() == key }
        } else {
            protectedFolders.append(url.standardizedFileURL)
        }
    }

    func isProtected(_ url: URL) -> Bool {
        protectedFolders.contains { $0.path.lowercased() == url.path.lowercased() }
    }

    private static func extensions(from text: String) -> Set<String> {
        Set(
            text.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }.filter { !$0.isEmpty }
        )
    }

    func refreshQLabLock() {
        guard let workspaceURL else {
            qlabWarning = nil
            qlabBlocksTrash = false
            return
        }
        if let warning = QLabProcess.warning(for: workspaceURL) {
            qlabWarning = warning.message
            qlabBlocksTrash = warning.blocksTrash
        } else {
            qlabWarning = nil
            qlabBlocksTrash = false
        }
    }

    func refreshFolderWarnings() {
        guard let workspace else {
            folderWarnings = []
            return
        }
        let folders = mode == .bundledCopy ? bundledFolders : contentFolders
        DispatchQueue.global(qos: .utility).async {
            let warnings = Analyzer.folderWarnings(
                workspaceDirectory: workspace.directory,
                folders: folders,
                mode: self.mode
            )
            DispatchQueue.main.async {
                self.folderWarnings = warnings
            }
        }
    }

    func relocalize() {
        updateMismatchWarning()
        refreshQLabLock()
        refreshFolderWarnings()
    }

    private func updateMismatchWarning() {
        guard let copies = workspace?.copiesFilesIntoProject else {
            modeMismatchWarning = nil
            return
        }
        switch mode {
        case .bundledCopy where copies == false:
            modeMismatchWarning = L10n.t("mode.mismatch.bundled")
        case .externalRefs where copies == true:
            modeMismatchWarning = L10n.t("mode.mismatch.external")
        default:
            modeMismatchWarning = nil
        }
    }
}

private final class ProgressThrottle {
    private var lastFlush: CFAbsoluteTime = 0
    private let interval: CFAbsoluteTime = 0.2

    func update(_ key: String, _ count: Int, apply: @escaping (String, Int) -> Void) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFlush >= interval else { return }
        lastFlush = now
        DispatchQueue.main.async {
            apply(key, count)
        }
    }
}

enum RecentsStore {
    private static let key = "recentWorkspaces"

    static func load() -> [RecentWorkspace] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([RecentWorkspace].self, from: data) else {
            return []
        }
        return items.filter(\.isAvailable)
    }

    static func save(_ items: [RecentWorkspace]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
