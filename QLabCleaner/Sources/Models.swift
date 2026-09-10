import Foundation

enum ProjectMode: String, Equatable {
    case bundledCopy
    case externalRefs

    var title: String {
        switch self {
        case .bundledCopy: return L10n.t("mode.bundled.title")
        case .externalRefs: return L10n.t("mode.external.title")
        }
    }

    var summary: String {
        switch self {
        case .bundledCopy: return L10n.t("mode.bundled.body")
        case .externalRefs: return L10n.t("mode.external.body")
        }
    }

    var titleKey: String {
        switch self {
        case .bundledCopy: return "mode.bundled.title"
        case .externalRefs: return "mode.external.title"
        }
    }
}

enum MediaKind: String {
    case audio
    case video
    case image
    case midi
    case other

    var symbol: String {
        switch self {
        case .audio: return "waveform"
        case .video: return "film"
        case .image: return "photo"
        case .midi: return "pianokeys"
        case .other: return "doc"
        }
    }

    var groupTitle: String {
        switch self {
        case .audio: return L10n.t("kind.audio")
        case .video: return L10n.t("kind.video")
        case .image: return L10n.t("kind.image")
        case .midi: return L10n.t("kind.midi")
        case .other: return L10n.t("kind.other")
        }
    }

    var label: String {
        switch self {
        case .audio: return L10n.t("kind.audio")
        case .video: return L10n.t("kind.video")
        case .image: return L10n.t("kind.image")
        case .midi: return L10n.t("kind.midi")
        case .other: return L10n.t("kind.file")
        }
    }

    static let displayOrder: [MediaKind] = [.audio, .video, .image, .midi, .other]


    static func from(fileName: String) -> MediaKind {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "wav", "aiff", "aif", "mp3", "m4a", "aac", "flac", "caf", "ogg", "wma":
            return .audio
        case "mov", "mp4", "m4v", "mpg", "mpeg", "avi", "mkv", "webm":
            return .video
        case "png", "jpg", "jpeg", "tif", "tiff", "gif", "bmp", "heic", "webp", "psd":
            return .image
        case "mid", "midi":
            return .midi
        default:
            return .other
        }
    }
}

struct CueReference: Hashable, Identifiable {
    var id: String { "\(type)-\(number)-\(uniqueID)" }
    let uniqueID: String
    let type: String
    let number: String
    let name: String
    let armed: Bool

    var label: String {
        let typeLabel: String
        switch type {
        case "VideoCue": typeLabel = "Video"
        case "AudioCue": typeLabel = "Audio"
        case "MIDIFileCue": typeLabel = "MIDI"
        case "Map", "pathImageAlias", "imageAlias": typeLabel = "Map"
        case "Mask", "maskAlias": typeLabel = "Mask"
        default: typeLabel = type.replacingOccurrences(of: "Cue", with: "")
        }
        if !number.isEmpty && !name.isEmpty {
            return "\(typeLabel) \(number) · \(name)"
        }
        if !number.isEmpty {
            return "\(typeLabel) \(number)"
        }
        if !name.isEmpty {
            return "\(typeLabel) · \(name)"
        }
        return typeLabel
    }
}

struct ReferencedMedia: Hashable, Identifiable {
    var id: String { relativePath.isEmpty ? lastKnownPath : relativePath }
    let relativePath: String
    let lastKnownPath: String
    let fileName: String
    let cues: [CueReference]

    var kind: MediaKind { MediaKind.from(fileName: fileName) }
    var usageCount: Int { max(cues.count, 1) }
    var displayPath: String { relativePath.isEmpty ? lastKnownPath : relativePath }
    var identityKey: String {
        if !relativePath.isEmpty { return relativePath.lowercased() }
        if !lastKnownPath.isEmpty { return lastKnownPath.lowercased() }
        return fileName.lowercased()
    }
}

struct ScannedFile: Hashable, Identifiable {
    var id: String { url.path }
    let url: URL
    let scanRoot: URL
    let relativePath: String
    let size: Int64
    let modifiedAt: Date

    var fileName: String { url.lastPathComponent }
    var kind: MediaKind { MediaKind.from(fileName: fileName) }
}

struct FileMatch: Hashable, Identifiable {
    var id: String { file.url.path }
    let file: ScannedFile
    let reference: ReferencedMedia?
    let status: Status
    var duplicateNames: [String] = []

    enum Status: String {
        case used
        case unused
    }
}

struct AnalysisResult {
    let workspaceURL: URL
    let workspaceDirectory: URL
    let mode: ProjectMode
    let copiesFilesIntoProject: Bool?
    let scannedRoots: [URL]
    let referenced: [ReferencedMedia]
    let used: [FileMatch]
    let unused: [FileMatch]
    let missing: [ReferencedMedia]
    let backupOnly: [ReferencedMedia]
    let backupFiles: [URL]
    let protectedSkipped: [FileMatch]
    let warnings: [String]

    var usedBytes: Int64 { used.reduce(0) { $0 + $1.file.size } }
    var unusedBytes: Int64 { unused.reduce(0) { $0 + $1.file.size } }
    var protectedBytes: Int64 { protectedSkipped.reduce(0) { $0 + $1.file.size } }
    var unusedDuplicateCount: Int { unused.filter { !$0.duplicateNames.isEmpty }.count }
    var scannedBytes: Int64 { usedBytes + unusedBytes + protectedBytes }
}

struct RecentWorkspace: Codable, Identifiable, Equatable {
    var id: String { workspacePath.lowercased() }
    let workspacePath: String
    let modeRaw: String
    let contentFolderPaths: [String]
    let openedAt: Date

    var url: URL { URL(fileURLWithPath: workspacePath) }
    var mode: ProjectMode { ProjectMode(rawValue: modeRaw) ?? .bundledCopy }
    var isAvailable: Bool { FileManager.default.fileExists(atPath: workspacePath) }
}

enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: bytes)
    }
}

enum FileSort: String, CaseIterable, Identifiable {
    case name
    case kind
    case date
    case size

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return L10n.t("results.sort.name")
        case .kind: return L10n.t("results.sort.kind")
        case .date: return L10n.t("results.sort.date")
        case .size: return L10n.t("results.sort.size")
        }
    }

    func sorted(_ files: [FileMatch]) -> [FileMatch] {
        switch self {
        case .name:
            return files.sorted { $0.file.fileName.localizedStandardCompare($1.file.fileName) == .orderedAscending }
        case .kind:
            return files.sorted {
                if $0.file.kind != $1.file.kind { return $0.file.kind.label < $1.file.kind.label }
                return $0.file.fileName.localizedStandardCompare($1.file.fileName) == .orderedAscending
            }
        case .date:
            return files.sorted { $0.file.modifiedAt > $1.file.modifiedAt }
        case .size:
            return files.sorted { $0.file.size > $1.file.size }
        }
    }

    func sortedMissing(_ files: [ReferencedMedia]) -> [ReferencedMedia] {
        switch self {
        case .name, .date, .size:
            return files.sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
        case .kind:
            return files.sorted {
                if $0.kind != $1.kind { return $0.kind.label < $1.kind.label }
                return $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
            }
        }
    }

    var groupsByKind: Bool { self == .kind }
}

enum FileGroups {
    static func grouped(_ files: [FileMatch]) -> [(MediaKind, [FileMatch])] {
        MediaKind.displayOrder.compactMap { kind in
            let items = files.filter { $0.file.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }

    static func groupedMissing(_ files: [ReferencedMedia]) -> [(MediaKind, [ReferencedMedia])] {
        MediaKind.displayOrder.compactMap { kind in
            let items = files.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }
}
