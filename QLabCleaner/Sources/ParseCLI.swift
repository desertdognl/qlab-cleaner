import Foundation

enum ParseCLI {
    static func run() {
        let raw = Array(CommandLine.arguments.dropFirst())
        let includeBackups = raw.contains("--backups")
        let args = raw.filter { $0 != "--backups" }
        guard let path = args.first else {
            fputs("usage: qlab-parse [--backups] <file.qlab5> [content folders...]\n", stderr)
            exit(2)
        }
        let workspaceURL = URL(fileURLWithPath: path)
        do {
            var url = workspaceURL
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                url = try QLabParser.findWorkspaceFile(in: url)
            }
            let workspace = try QLabParser.parse(workspaceURL: url)
            print("workspace: \(workspace.url.lastPathComponent)")
            print("directory: \(workspace.directory.path)")
            print("doAutoCopy: \(workspace.copiesFilesIntoProject.map { $0 ? "true" : "false" } ?? "unknown")")
            print("referenced: \(workspace.referencedFiles.count)")
            for item in workspace.referencedFiles {
                let cues = item.cues.map(\.label).joined(separator: ", ")
                let times = item.cues.isEmpty ? "" : " \(item.usageCount)×"
                print("  - \(item.relativePath.isEmpty ? item.lastKnownPath : item.relativePath)  [\(item.kind.label)]\(times) \(cues)")
            }

            let extra = args.dropFirst().map { URL(fileURLWithPath: $0) }
            let mode: ProjectMode = extra.isEmpty ? .bundledCopy : .externalRefs
            let result = try Analyzer.analyze(
                workspace: workspace,
                mode: mode,
                extraFolders: extra,
                includeBackups: includeBackups
            )
            print("used: \(result.used.count) (\(ByteFormat.string(result.usedBytes)))")
            for item in result.used {
                let times = item.reference.map { "\($0.usageCount)×" } ?? ""
                print("  - \(item.file.relativePath) \(times)")
            }
            print("unused: \(result.unused.count) (\(ByteFormat.string(result.unusedBytes)))")
            for item in result.unused { print("  - \(item.file.relativePath)") }
            print("missing: \(result.missing.count)")
            for item in result.missing { print("  - \(item.displayPath) \(item.usageCount)×") }
            if includeBackups {
                print("backups: \(result.backupFiles.count)")
                for url in result.backupFiles { print("  - \(url.lastPathComponent)") }
                print("only in backup: \(result.backupOnly.count)")
                for item in result.backupOnly { print("  - \(item.displayPath) \(item.usageCount)×") }
            }
            print("scanned total: \(ByteFormat.string(result.scannedBytes))")
            for warning in result.warnings { print("warning: \(warning)") }
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
