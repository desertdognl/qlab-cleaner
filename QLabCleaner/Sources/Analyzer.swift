import Foundation
import CryptoKit

enum Analyzer {
    static let ignoredFileNames: Set<String> = [".DS_Store", "Icon\r", "Icon"]
    static let ignoredExtensions: Set<String> = ["qlab5", "qlab4", "qlab5backup", "qlab4backup"]

    static func analyze(
        workspace: QLabWorkspace,
        mode: ProjectMode,
        extraFolders: [URL],
        protectedFolders: [URL] = [],
        protectedExtensions: Set<String> = [],
        ignoreDisarmed: Bool = false,
        includeBackups: Bool = false,
        progress: ((String, Int) -> Void)? = nil
    ) throws -> AnalysisResult {
        let roots = try scanRoots(workspace: workspace, mode: mode, extraFolders: extraFolders)
        let scanned = try roots.flatMap { try scanFiles(in: $0, progress: progress) }
        progress?("progress.matching", scanned.count)
        let protectedRoots = protectedFolders.map { $0.standardizedFileURL.path.lowercased() }
        let referenced = activeReferences(workspace.referencedFiles, ignoreDisarmed: ignoreDisarmed)

        var used: [FileMatch] = []
        var unused: [FileMatch] = []
        var protectedSkipped: [FileMatch] = []
        var claimedKeys: Set<String> = []

        for file in scanned {
            if let reference = match(file: file, referenced: referenced, workspaceDirectory: workspace.directory) {
                used.append(FileMatch(file: file, reference: reference, status: .used))
                claimedKeys.insert(reference.id)
            } else if isProtected(file, roots: protectedRoots, extensions: protectedExtensions) {
                protectedSkipped.append(FileMatch(file: file, reference: nil, status: .unused))
            } else {
                unused.append(FileMatch(file: file, reference: nil, status: .unused))
            }
        }

        used.sort { $0.file.fileName.localizedStandardCompare($1.file.fileName) == .orderedAscending }
        unused.sort { $0.file.fileName.localizedStandardCompare($1.file.fileName) == .orderedAscending }
        protectedSkipped.sort { $0.file.fileName.localizedStandardCompare($1.file.fileName) == .orderedAscending }

        annotateDuplicates(&used, &unused, progress: progress)

        let missing = referenced.filter { item in
            !claimedKeys.contains(item.id)
        }

        var warnings = folderWarnings(
            workspaceDirectory: workspace.directory,
            folders: roots,
            mode: mode
        )

        var backupOnly: [ReferencedMedia] = []
        var backupFiles: [URL] = []
        if includeBackups {
            backupFiles = findBackupFiles(near: workspace.url)
            if !backupFiles.isEmpty {
                progress?("progress.backups", backupFiles.count)
            }
            let currentKeys = Set(referenced.map(\.identityKey))
            var extras: [String: ReferencedMedia] = [:]
            for url in backupFiles {
                do {
                    let parsed = try QLabParser.parse(workspaceURL: url)
                    let refs = activeReferences(parsed.referencedFiles, ignoreDisarmed: ignoreDisarmed)
                    for ref in refs {
                        let key = ref.identityKey
                        if !currentKeys.contains(key), extras[key] == nil {
                            extras[key] = ref
                        }
                    }
                } catch {
                    warnings.append(L10n.t("backups.parseFailed", url.lastPathComponent))
                }
            }
            backupOnly = extras.values.sorted {
                $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
            }
        }

        return AnalysisResult(
            workspaceURL: workspace.url,
            workspaceDirectory: workspace.directory,
            mode: mode,
            copiesFilesIntoProject: workspace.copiesFilesIntoProject,
            scannedRoots: roots,
            referenced: referenced,
            used: used,
            unused: unused,
            missing: missing,
            backupOnly: backupOnly,
            backupFiles: backupFiles,
            protectedSkipped: protectedSkipped,
            warnings: warnings
        )
    }

    static func findBackupFiles(near workspaceURL: URL) -> [URL] {
        let fm = FileManager.default
        let directory = workspaceURL.deletingLastPathComponent()
        var found: [URL] = []

        func collect(in folder: URL) {
            guard let items = try? fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { return }
            for item in items where item.pathExtension.lowercased() == "qlab5backup" {
                if item.standardizedFileURL.path.lowercased() != workspaceURL.standardizedFileURL.path.lowercased() {
                    found.append(item.standardizedFileURL)
                }
            }
        }

        collect(in: directory)
        if let items = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for item in items {
                let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDirectory else { continue }
                let name = item.lastPathComponent.lowercased()
                if name == "backups" || name.hasSuffix(" backups") {
                    collect(in: item)
                }
            }
        }

        var seen = Set<String>()
        return found
            .filter { seen.insert($0.path.lowercased()).inserted }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static let largeFolderBytes: Int64 = 5 * 1024 * 1024 * 1024
    static let largeFileCount = 2500

    static func folderWarnings(workspaceDirectory: URL, folders: [URL], mode: ProjectMode) -> [String] {
        var warnings: [String] = []
        for folder in folders {
            if mode == .externalRefs, !isNearWorkspace(folder, workspaceDirectory: workspaceDirectory) {
                warnings.append(L10n.t("folders.far", folder.lastPathComponent))
            }
            let stats = folderStats(for: folder)
            if stats.bytes >= largeFolderBytes || stats.count >= largeFileCount {
                warnings.append(L10n.t("folders.large", folder.lastPathComponent, stats.count, ByteFormat.string(stats.bytes)))
            }
        }
        return warnings
    }

    static func discoverBundledFolders(in workspaceDirectory: URL) throws -> [URL] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: workspaceDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return contents.filter { url in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { return false }
            let name = url.lastPathComponent
            if name.lowercased().hasSuffix(" backups") { return false }
            if name.lowercased() == "backups" { return false }
            return true
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func suggestedFolders(from workspace: QLabWorkspace) -> [URL] {
        var folders: [URL] = []
        var seen = Set<String>()
        for ref in workspace.referencedFiles {
            let resolved = resolvePath(ref.relativePath, relativeTo: workspace.directory)
            let folder = resolved.deletingLastPathComponent().standardizedFileURL
            let key = folder.path.lowercased()
            if !seen.contains(key), FileManager.default.fileExists(atPath: folder.path) {
                seen.insert(key)
                folders.append(folder)
            }
        }
        return folders
    }

    private static func scanRoots(
        workspace: QLabWorkspace,
        mode: ProjectMode,
        extraFolders: [URL]
    ) throws -> [URL] {
        switch mode {
        case .bundledCopy:
            let discovered = try discoverBundledFolders(in: workspace.directory)
            return uniqueURLs(discovered)
        case .externalRefs:
            return uniqueURLs(extraFolders)
        }
    }

    private static func scanFiles(in root: URL, progress: ((String, Int) -> Void)? = nil) throws -> [ScannedFile] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isHiddenKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [ScannedFile] = []
        for case let url as URL in enumerator {
            if shouldSkipDirectory(url) {
                enumerator.skipDescendants()
                continue
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            guard values.isRegularFile == true else { continue }
            if shouldSkipFile(url) { continue }

            let relative = relativePath(of: url, to: root)
            files.append(
                ScannedFile(
                    url: url.standardizedFileURL,
                    scanRoot: root,
                    relativePath: relative,
                    size: Int64(values.fileSize ?? 0),
                    modifiedAt: values.contentModificationDate ?? .distantPast
                )
            )
            if files.count == 1 || files.count % 50 == 0 {
                progress?("progress.scanning", files.count)
            }
        }
        if !files.isEmpty {
            progress?("progress.scanning", files.count)
        }
        return files
    }

    private static func match(file: ScannedFile, referenced: [ReferencedMedia], workspaceDirectory: URL) -> ReferencedMedia? {
        let filePath = standardized(file.url.path)

        for ref in referenced {
            if !ref.relativePath.isEmpty {
                let resolved = standardized(resolvePath(ref.relativePath, relativeTo: workspaceDirectory).path)
                if pathsEqual(filePath, resolved) { return ref }

                let relativeLower = ref.relativePath.lowercased()
                if filePath.lowercased().hasSuffix("/" + relativeLower) { return ref }
                if file.relativePath.lowercased() == relativeLower { return ref }
            }

            if !ref.lastKnownPath.isEmpty, pathsEqual(filePath, standardized(ref.lastKnownPath)) {
                return ref
            }
        }

        let sameName = referenced.filter {
            $0.fileName.compare(file.fileName, options: [.caseInsensitive]) == .orderedSame
        }
        if sameName.count == 1 {
            return sameName[0]
        }
        return nil
    }

    private static func isNearWorkspace(_ folder: URL, workspaceDirectory: URL) -> Bool {
        let folderPath = folder.standardizedFileURL.path.lowercased()
        let workspacePath = workspaceDirectory.standardizedFileURL.path.lowercased()
        let parentPath = workspaceDirectory.deletingLastPathComponent().standardizedFileURL.path.lowercased()
        if folderPath == workspacePath { return true }
        if folderPath.hasPrefix(workspacePath + "/") { return true }
        if workspacePath.hasPrefix(folderPath + "/") { return true }
        if folderPath == parentPath { return true }
        if folder.deletingLastPathComponent().standardizedFileURL.path.lowercased() == parentPath { return true }
        return false
    }

    static func folderStats(for root: URL) -> (count: Int, bytes: Int64) {
        (try? scanFiles(in: root)).map { files in
            (files.count, files.reduce(0) { $0 + $1.size })
        } ?? (0, 0)
    }

    private static func shouldSkipFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if ignoredFileNames.contains(name) { return true }
        if name.hasPrefix(".") { return true }
        return ignoredExtensions.contains(url.pathExtension.lowercased())
    }

    private static func shouldSkipDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name.hasSuffix(" backups") || name == "backups"
    }

    private static func relativePath(of url: URL, to root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        if filePath.lowercased().hasPrefix(rootPath.lowercased()) {
            let sliced = String(filePath.dropFirst(rootPath.count))
            return sliced.hasPrefix("/") ? String(sliced.dropFirst()) : sliced
        }
        return url.lastPathComponent
    }

    static func resolvePath(_ relativePath: String, relativeTo directory: URL) -> URL {
        let combined = (directory.path as NSString).appendingPathComponent(relativePath)
        return URL(fileURLWithPath: (combined as NSString).standardizingPath)
    }

    private static func standardized(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private static func pathsEqual(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive]) == .orderedSame
    }

    private static func activeReferences(_ files: [ReferencedMedia], ignoreDisarmed: Bool) -> [ReferencedMedia] {
        guard ignoreDisarmed else { return files }
        return files.compactMap { media in
            let cues = media.cues.filter(\.armed)
            guard !cues.isEmpty else { return nil }
            return ReferencedMedia(
                relativePath: media.relativePath,
                lastKnownPath: media.lastKnownPath,
                fileName: media.fileName,
                cues: cues
            )
        }
    }

    private static func isProtected(_ file: ScannedFile, roots: [String], extensions: Set<String>) -> Bool {
        let path = file.url.path.lowercased()
        if roots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }
        return extensions.contains(file.url.pathExtension.lowercased())
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls {
            let key = url.standardizedFileURL.path.lowercased()
            if seen.insert(key).inserted {
                result.append(url.standardizedFileURL)
            }
        }
        return result
    }

    private static func annotateDuplicates(
        _ used: inout [FileMatch],
        _ unused: inout [FileMatch],
        progress: ((String, Int) -> Void)?
    ) {
        let all = used + unused
        guard !all.isEmpty else { return }
        var hashes: [String: String] = [:]
        for (index, match) in all.enumerated() {
            if index == 0 || (index + 1) % 4 == 0 {
                progress?("progress.hashing", index + 1)
            }
            if let hash = sha256(of: match.file.url) {
                hashes[match.file.url.path] = hash
            }
        }
        progress?("progress.hashing", all.count)

        var byHash: [String: [FileMatch]] = [:]
        for match in all {
            guard let hash = hashes[match.file.url.path] else { continue }
            byHash[hash, default: []].append(match)
        }

        func peers(for match: FileMatch) -> [String] {
            guard let hash = hashes[match.file.url.path],
                  let group = byHash[hash],
                  group.count > 1 else { return [] }
            return group
                .filter { $0.file.url.path != match.file.url.path }
                .map(\.file.fileName)
        }

        for index in used.indices {
            used[index].duplicateNames = peers(for: used[index])
        }
        for index in unused.indices {
            unused[index].duplicateNames = peers(for: unused[index])
        }
    }

    private static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
