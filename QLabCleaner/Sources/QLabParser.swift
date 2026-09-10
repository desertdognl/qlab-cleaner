import Foundation

struct QLabWorkspace {
    let url: URL
    let directory: URL
    let copiesFilesIntoProject: Bool?
    let referencedFiles: [ReferencedMedia]
}

enum QLabParser {
    private static let aliasKeys: Set<String> = [
        "fileTarget", "pathImageAlias", "imageAlias", "maskAlias"
    ]

    static func parse(workspaceURL: URL) throws -> QLabWorkspace {
        let data: Data
        do {
            data = try Data(contentsOf: workspaceURL)
        } catch {
            throw ParserError.unreadableFile
        }

        let root = try KeyedArchive(data: data)
        let copies = root.boolSetting("doAutoCopy")

        var archives = [root]
        archives.append(contentsOf: root.nestedArchives())

        var filesByKey: [String: ReferencedMedia] = [:]

        for (archiveIndex, archive) in archives.enumerated() {
            var aliasMap: [Int: String] = [:]
            for (index, object) in archive.objects.enumerated() {
                guard archive.className(of: object) == "F53Alias" else { continue }
                guard let dict = object as? [String: Any] else { continue }
                let relative = archive.string(from: dict["relativePath"])
                let lastKnown = archive.string(from: dict["lastKnownPath"])
                let fileName = (relative as NSString).lastPathComponent
                let fallbackName = (lastKnown as NSString).lastPathComponent
                let name = fileName.isEmpty ? fallbackName : fileName
                guard !name.isEmpty else { continue }

                let key = Self.dedupeKey(relativePath: relative, lastKnownPath: lastKnown, fileName: name)
                aliasMap[index] = key
                if filesByKey[key] == nil {
                    filesByKey[key] = ReferencedMedia(
                        relativePath: relative,
                        lastKnownPath: lastKnown,
                        fileName: name,
                        cues: []
                    )
                }
            }

            for object in archive.objects {
                guard let dict = object as? [String: Any] else { continue }
                let className = archive.className(of: object) ?? ""
                let uniqueID = archive.string(from: dict["uniqueID"])
                if uniqueID.hasPrefix("audio-for-video-") { continue }
                if archiveIndex == 0, className.hasSuffix("Cue") { continue }

                for (key, value) in dict {
                    guard key != "$class" else { continue }
                    guard let targetIndex = archive.uidIndex(value),
                          let mediaKey = aliasMap[targetIndex],
                          var media = filesByKey[mediaKey] else { continue }
                    if !Self.aliasKeys.contains(key), archive.className(of: archive.resolve(value)) != "F53Alias" {
                        continue
                    }

                    let cueType: String
                    switch key {
                    case "pathImageAlias", "imageAlias": cueType = "Map"
                    case "maskAlias": cueType = "Mask"
                    default: cueType = className.isEmpty ? key : className
                    }

                    let cue = CueReference(
                        uniqueID: uniqueID.isEmpty ? "\(className)-\(key)-\(mediaKey)" : uniqueID + "-" + key,
                        type: cueType,
                        number: archive.string(from: dict["number"]),
                        name: archive.string(from: dict["name"]),
                        armed: archive.boolValue(dict["armed"]) ?? true
                    )
                    if !media.cues.contains(where: { $0.uniqueID == cue.uniqueID && $0.type == cue.type }) {
                        media = ReferencedMedia(
                            relativePath: media.relativePath,
                            lastKnownPath: media.lastKnownPath,
                            fileName: media.fileName,
                            cues: media.cues + [cue]
                        )
                        filesByKey[mediaKey] = media
                    }
                }
            }
        }

        let referenced = filesByKey.values.sorted {
            $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
        }

        return QLabWorkspace(
            url: workspaceURL,
            directory: workspaceURL.deletingLastPathComponent(),
            copiesFilesIntoProject: copies,
            referencedFiles: referenced
        )
    }

    static func findWorkspaceFiles(in directory: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return contents
            .filter { $0.pathExtension.lowercased() == "qlab5" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func findWorkspaceFile(in directory: URL) throws -> URL {
        let files = try findWorkspaceFiles(in: directory)
        if files.isEmpty { throw ParserError.noWorkspaceFile }
        if files.count == 1 { return files[0] }
        throw ParserError.multipleWorkspaces(files.map(\.lastPathComponent))
    }

    private static func dedupeKey(relativePath: String, lastKnownPath: String, fileName: String) -> String {
        if !relativePath.isEmpty {
            return relativePath.lowercased()
        }
        if !lastKnownPath.isEmpty {
            return lastKnownPath.lowercased()
        }
        return fileName.lowercased()
    }
}
