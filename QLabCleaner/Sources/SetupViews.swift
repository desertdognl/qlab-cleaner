import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
            Group {
                if store.showingAbout {
                    AboutView()
                } else {
                    switch store.step {
                    case .chooseMode:
                        ModePickerView()
                    case .configure:
                        SetupView()
                    case .results:
                        ResultsView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: loc.language) { _ in
            store.relocalize()
        }
    }
}

struct HeaderBar: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(AppInfo.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            LanguageSwitch()
            if let logo = NSImage.logo {
                Button {
                    store.showingAbout.toggle()
                } label: {
                    Image(nsImage: logo)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 26)
                        .opacity(0.94)
                }
                .buttonStyle(.plain)
                .help(loc.t("about.title"))
            }
            Text(AppInfo.versionLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .themeControl(radius: 20)
        }
        .padding(.leading, 78)
        .padding(.trailing, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Theme.bgElevated.opacity(0.55))
        .overlay(Divider().background(Theme.stroke), alignment: .bottom)
    }

    private var subtitle: String {
        if store.showingAbout {
            return loc.t("about.title")
        }
        switch store.step {
        case .chooseMode:
            return loc.t("header.chooseMode")
        case .configure:
            return loc.t(store.mode.titleKey)
        case .results:
            return store.workspaceURL?.lastPathComponent ?? loc.t(store.mode.titleKey)
        }
    }
}

struct LanguageSwitch: View {
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "globe")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textFaint)
                .padding(.leading, 8)
                .padding(.trailing, 2)
            ForEach(AppLanguage.allCases) { language in
                Button {
                    loc.language = language
                } label: {
                    Text(language.code)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(loc.language == language ? Color.black : Theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(loc.language == language ? Theme.accent : Color.clear)
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .help(language.nativeName)
            }
        }
        .padding(3)
        .padding(.trailing, 2)
        .themeControl(radius: 20)
        .animation(.easeInOut(duration: 0.15), value: loc.language)
        .help(loc.t("language.label"))
    }
}

extension NSImage {
    static var logo: NSImage? {
        let candidates = [
            Bundle.main.url(forResource: "logo_full_white", withExtension: "png"),
            Bundle.main.resourceURL?.appendingPathComponent("logo_full_white.png")
        ].compactMap { $0 }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    static var bmcButton: NSImage? {
        let candidates = [
            Bundle.main.url(forResource: "bmc-button", withExtension: "png"),
            Bundle.main.resourceURL?.appendingPathComponent("bmc-button.png")
        ].compactMap { $0 }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

struct AboutView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button {
                    store.showingAbout = false
                } label: {
                    Label(loc.t("about.close"), systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)

            Spacer()

            if let logo = NSImage.logo {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 420, maxHeight: 120)
                    .opacity(0.96)
            }

            Text(AppInfo.versionLabel)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.textMuted)

            Button {
                NSWorkspace.shared.open(AppInfo.coffeeURL)
            } label: {
                if let button = NSImage.bmcButton {
                    Image(nsImage: button)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 56)
                } else {
                    Text(loc.t("about.coffee"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color(red: 1, green: 0.867, blue: 0))
                        .cornerRadius(12)
                }
            }
            .buttonStyle(.plain)
            .help(loc.t("about.coffee"))
            .padding(.top, 8)

            Button {
                NSWorkspace.shared.open(AppInfo.githubReleasesURL)
            } label: {
                Text(loc.t("about.github"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ModePickerView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 8) {
                Text(loc.t("mode.section"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text(loc.t("mode.headline"))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                Text(loc.t("mode.intro"))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            HStack(spacing: 18) {
                ModeCard(
                    title: loc.t("mode.bundled.title"),
                    qlabSetting: loc.t("mode.bundled.qlab"),
                    bodyText: loc.t("mode.bundled.body"),
                    symbol: "folder.fill.badge.plus"
                ) {
                    store.selectMode(.bundledCopy)
                }
                ModeCard(
                    title: loc.t("mode.external.title"),
                    qlabSetting: loc.t("mode.external.qlab"),
                    bodyText: loc.t("mode.external.body"),
                    symbol: "link"
                ) {
                    store.selectMode(.externalRefs)
                }
            }
            .padding(.horizontal, 40)

            if !store.recents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc.t("recents.title"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    ForEach(store.recents) { recent in
                        HStack(spacing: 12) {
                            Button {
                                store.openRecent(recent)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: recent.mode == .bundledCopy ? "folder.fill.badge.plus" : "link")
                                        .foregroundColor(Theme.accent)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(recent.url.lastPathComponent)
                                            .font(.system(size: 13.5, weight: .medium))
                                            .foregroundColor(Theme.text)
                                        Text("\(loc.t(recent.mode.titleKey))  ·  \(recent.url.deletingLastPathComponent().path)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(Theme.textFaint)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            Button {
                                store.removeRecent(recent)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.textMuted)
                            }
                            .buttonStyle(.plain)
                            .help(loc.t("recents.remove"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .themeControl()
                    }
                }
                .frame(maxWidth: 860)
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding(32)
    }
}

struct ModeCard: View {
    let title: String
    let qlabSetting: String
    let bodyText: String
    let symbol: String
    let action: () -> Void
    @EnvironmentObject private var loc: Localization
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.accentSoft)
                        .frame(width: 48, height: 48)
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.leading)
                Text(qlabSetting)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.accent)
                Text(bodyText)
                    .font(.system(size: 13.5))
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                HStack {
                    Text(loc.t("mode.choose"))
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(hovering ? Color.black : Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(hovering ? Theme.accent : Theme.surface)
                .cornerRadius(20)
            }
            .padding(22)
            .frame(maxWidth: 420, minHeight: 280, alignment: .leading)
            .background(hovering ? Theme.surfaceHover : Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(hovering ? Theme.accent.opacity(0.65) : Theme.stroke, lineWidth: 1)
            )
            .cornerRadius(Theme.radius)
            .shadow(color: hovering ? Theme.accent.opacity(0.12) : Color.clear, radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovering)
    }
}

struct SetupView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var loc: Localization
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    backRow
                    workspaceCard
                    foldersCard
                    if let warning = store.modeMismatchWarning {
                        Notice(text: warning, tone: .warning)
                    }
                    if let suggested = store.suggestedMode, suggested != store.mode {
                        HStack(alignment: .top, spacing: 12) {
                            Notice(
                                text: loc.t("mode.suggest", loc.t(suggested.titleKey)),
                                tone: .info
                            )
                            GhostButton(title: loc.t("mode.switch"), symbol: "arrow.triangle.2.circlepath") {
                                store.applySuggestedMode()
                            }
                        }
                    }
                    ForEach(store.folderWarnings, id: \.self) { warning in
                        Notice(text: warning, tone: .warning)
                    }
                    if let qlab = store.qlabWarning {
                        Notice(text: qlab, tone: store.qlabBlocksTrash ? .danger : .warning)
                    }
                    if let error = store.errorMessage {
                        Notice(text: error, tone: .danger)
                    }
                }
                .padding(28)
            }
            footer
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted, perform: handleDrop)
    }

    private var backRow: some View {
        Button {
            store.reset()
        } label: {
            Label(loc.t("mode.other"), systemImage: "chevron.left")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textMuted)
        }
        .buttonStyle(.plain)
    }

    private var workspaceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(loc.t("workspace.title"))
            if let url = store.workspaceURL {
                FileChip(
                    url: url,
                    subtitle: store.workspace?.directory.path ?? url.deletingLastPathComponent().path,
                    onRemove: {
                        store.workspaceURL = nil
                        store.workspace = nil
                        store.bundledFolders = []
                        store.modeMismatchWarning = nil
                        store.workspaceCandidates = []
                    }
                )
            } else if !store.workspaceCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.t("workspace.multiple"))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                    ForEach(store.workspaceCandidates, id: \.path) { url in
                        Button {
                            store.loadWorkspace(from: url)
                        } label: {
                            FileChip(url: url, subtitle: url.path, removable: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                DropHint(
                    title: store.mode == .bundledCopy
                        ? loc.t("workspace.drop.bundled")
                        : loc.t("workspace.drop.external"),
                    subtitle: store.mode == .bundledCopy
                        ? loc.t("workspace.drop.bundledHint")
                        : loc.t("workspace.drop.externalHint"),
                    symbol: "q.square",
                    highlighted: dropTargeted
                )
            }
            HStack(spacing: 10) {
                GhostButton(title: loc.t("workspace.pickFile"), symbol: "doc.badge.plus") {
                    pickWorkspace()
                }
                if store.mode == .bundledCopy {
                    GhostButton(title: loc.t("workspace.pickFolder"), symbol: "folder.badge.plus") {
                        pickProjectFolder()
                    }
                }
            }
        }
        .padding(20)
        .themePanel()
    }

    private var foldersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(store.mode == .bundledCopy ? loc.t("folders.found") : loc.t("folders.content"))
            if store.mode == .bundledCopy {
                if store.workspace == nil {
                    Text(loc.t("workspace.needFirst"))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                } else if store.bundledFolders.isEmpty {
                    Text(loc.t("workspace.noneFound"))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.unused)
                } else {
                    ForEach(store.bundledFolders, id: \.path) { url in
                        FileChip(
                            url: url,
                            subtitle: url.path,
                            removable: false,
                            protectable: true,
                            isProtected: store.isProtected(url),
                            onToggleProtect: { store.toggleProtected(url) }
                        )
                    }
                }
            } else {
                if store.contentFolders.isEmpty {
                    Text(loc.t("workspace.addFolders"))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                } else {
                    ForEach(store.contentFolders, id: \.path) { url in
                        FileChip(
                            url: url,
                            subtitle: url.path,
                            removable: true,
                            onRemove: { store.removeContentFolder(url) },
                            protectable: true,
                            isProtected: store.isProtected(url),
                            onToggleProtect: { store.toggleProtected(url) }
                        )
                    }
                }
                GhostButton(title: loc.t("workspace.pickContent"), symbol: "folder.badge.plus") {
                    pickContentFolders()
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(loc.t("folders.protectedExt"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textFaint)
                TextField(loc.t("folders.protectedPlaceholder"), text: $store.protectedExtensionsText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .themeControl()
            }
            Toggle(loc.t("results.includeBackups"), isOn: $store.includeBackups)
                .toggleStyle(.checkbox)
                .font(.system(size: 13))
                .foregroundColor(Theme.text)
                .help(loc.t("results.includeBackupsHelp"))
        }
        .padding(20)
        .themePanel()
    }

    private var footer: some View {
        HStack {
            Text(statusLine)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
            Spacer()
            Button(action: store.analyze) {
                HStack(spacing: 8) {
                    if store.isWorking {
                        ProgressView().controlSize(.small)
                    }
                    Text(loc.t("results.show"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(canAnalyze ? Theme.accent : Theme.accent.opacity(0.35))
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            .disabled(!canAnalyze || store.isWorking)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(Theme.bgElevated)
        .overlay(Divider().background(Theme.stroke), alignment: .top)
    }

    private var canAnalyze: Bool {
        guard store.workspace != nil else { return false }
        if store.mode == .externalRefs { return !store.contentFolders.isEmpty }
        return true
    }

    private var statusLine: String {
        if store.isWorking {
            if let key = store.progressKey {
                return loc.t(key, store.progressCount)
            }
            return loc.t("workspace.reading")
        }
        if let workspace = store.workspace {
            return loc.t("workspace.mediaCount", workspace.referencedFiles.count, workspace.url.lastPathComponent)
        }
        return loc.t("workspace.noneChosen")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textMuted)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func pickWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = loc.t("workspace.pickFileMessage")
        if let qlab = UTType(filenameExtension: "qlab5") {
            panel.allowedContentTypes = [qlab]
        }
        if panel.runModal() == .OK, let url = panel.url {
            store.loadWorkspace(from: url)
        }
    }

    private func pickProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = loc.t("workspace.pickFolderMessage")
        if panel.runModal() == .OK, let url = panel.url {
            store.loadWorkspace(from: url)
        }
    }

    private func pickContentFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = loc.t("workspace.pickContentMessage")
        if panel.runModal() == .OK {
            store.addContentFolders(panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let urlItem = item as? URL {
                    url = urlItem
                } else {
                    url = nil
                }
                guard let url else { return }
                DispatchQueue.main.async {
                    store.loadWorkspace(from: url)
                }
            }
        }
        return true
    }
}

struct FileChip: View {
    let url: URL
    var subtitle: String? = nil
    var removable: Bool = true
    var onRemove: (() -> Void)? = nil
    var protectable: Bool = false
    var isProtected: Bool = false
    var onToggleProtect: (() -> Void)? = nil
    @EnvironmentObject private var loc: Localization

    private var isFolder: Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isFolder ? "folder.fill" : "doc.fill")
                .foregroundColor(Theme.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textFaint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            if protectable, let onToggleProtect {
                Button(action: onToggleProtect) {
                    Image(systemName: isProtected ? "lock.fill" : "lock.open")
                        .foregroundColor(isProtected ? Theme.unused : Theme.textMuted)
                }
                .buttonStyle(.plain)
                .help(isProtected ? loc.t("folders.protectedHelp") : loc.t("folders.protect"))
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(Theme.textMuted)
            }
            .buttonStyle(.plain)
            .help(loc.t("results.reveal"))
            if removable, let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .themeControl()
    }
}

struct DropHint: View {
    let title: String
    let subtitle: String
    let symbol: String
    var highlighted = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(highlighted ? Theme.accent : Theme.textFaint)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.text)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(highlighted ? Theme.accentSoft : Theme.surface.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                .foregroundColor(highlighted ? Theme.accent : Theme.strokeStrong)
        )
        .cornerRadius(Theme.radiusSmall)
    }
}

struct GhostButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(hovering ? Theme.surfaceHover : Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(hovering ? Theme.strokeStrong : Theme.stroke, lineWidth: 1)
                )
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct Notice: View {
    enum Tone { case warning, danger, info }
    let text: String
    var tone: Tone = .info

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tone == .danger ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(foreground)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .cornerRadius(Theme.radiusSmall)
    }

    private var foreground: Color {
        switch tone {
        case .warning: return Theme.unused
        case .danger: return Theme.danger
        case .info: return Theme.textMuted
        }
    }

    private var background: Color {
        switch tone {
        case .warning: return Theme.unusedSoft
        case .danger: return Theme.dangerSoft
        case .info: return Theme.surface
        }
    }
}
