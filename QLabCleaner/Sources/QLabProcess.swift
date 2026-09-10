import Foundation
import AppKit

enum QLabProcess {
    /// Figure 53’s QLab (3/4/5, …). Never match this app: `com.ddtools.qlabcleaner` contains “qlab”.
    static func runningQLabApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter(isFigure53QLab)
    }

    static func warning(for workspaceURL: URL) -> (message: String, blocksTrash: Bool)? {
        let apps = runningQLabApps()
        guard !apps.isEmpty else { return nil }
        if fileIsOpen(workspaceURL, by: apps) {
            return (L10n.t("qlab.open"), true)
        }
        return (L10n.t("qlab.running"), false)
    }

    private static func isFigure53QLab(_ app: NSRunningApplication) -> Bool {
        if app == NSRunningApplication.current { return false }
        let bundle = app.bundleIdentifier?.lowercased() ?? ""
        if bundle.hasPrefix("com.figure53.qlab") { return true }
        let name = (app.localizedName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return name == "qlab"
    }

    private static func fileIsOpen(_ url: URL, by apps: [NSRunningApplication]) -> Bool {
        let qlabPIDs = Set(apps.map { Int($0.processIdentifier) })
        guard !qlabPIDs.isEmpty else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-t", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        let pids = text.split(whereSeparator: \.isNewline).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return pids.contains(where: { qlabPIDs.contains($0) })
    }
}
