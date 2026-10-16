//
//  FinderSync.swift
//  FlickerExtension
//
//  Finder Sync extension principal class.
//

import Cocoa
import FinderSync

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private var actionDispatch: [Int: () -> Void] = [:]
    private var nextMenuTag = 100

    override init() {
        super.init()
        // 监视所有卷与用户目录，确保全盘任意位置（包括下载、桌面、外接卷）均可触发
        var watchedURLs = Set<URL>()
        watchedURLs.insert(URL(fileURLWithPath: "/"))
        watchedURLs.insert(URL(fileURLWithPath: "/Users"))
        watchedURLs.insert(URL(fileURLWithPath: "/Volumes"))
        watchedURLs.insert(URL(fileURLWithPath: "/System/Volumes/Data"))
        FIFinderSyncController.default().directoryURLs = watchedURLs

        // 监听配置更新通知，重置内存状态，下次点击右键立即直接读盘展示最新配置
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(configDidChange(_:)),
            name: SharedStore.configChangedNotification,
            object: nil
        )
    }

    @objc private func configDidChange(_ notification: Notification) {
        resetMenuState()
    }

    private func resetMenuState() {
        actionDispatch.removeAll()
        nextMenuTag = 100
    }

    private func registerAction(_ handler: @escaping () -> Void) -> Int {
        let tag = nextMenuTag
        nextMenuTag += 1
        actionDispatch[tag] = handler
        return tag
    }

    @objc private func handleMenuAction(_ sender: NSMenuItem) {
        actionDispatch[sender.tag]?()
    }

    // MARK: - Menu Generation

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "Flicker")
        resetMenuState()

        let menuSettings = SharedStore.loadMenuSettings()
        guard menuSettings.finderExtensionEnabled else { return menu }

        // 1. 空白区域右键（在文件夹内部空白处点击）
        if menuKind == .contextualMenuForContainer {
            if let currentFolderURL = FIFinderSyncController.default().targetedURL() {
                populateMenu(targets: [currentFolderURL], isContainer: true, into: menu, settings: menuSettings)
            }
            return menu
        }

        // 2. 选中文件或文件夹右键
        if menuKind == .contextualMenuForItems || menuKind == .contextualMenuForSidebar {
            if let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty {
                populateMenu(targets: urls, isContainer: false, into: menu, settings: menuSettings)
            }
            return menu
        }

        return menu
    }

    // MARK: - Menu Population

    private func populateMenu(targets: [URL], isContainer: Bool, into menu: NSMenu, settings: MenuSettings) {
        guard let firstTarget = targets.first else { return }
        let targetDirectory = getTargetDirectory(for: firstTarget)

        // 1. 打开方式列表（先读取配置，若配置为空则自动智能探测已安装应用）
        let availableEntries = resolveAvailableEntries(for: targets, isContainer: isContainer)
        if !availableEntries.isEmpty {
            let directEntries = availableEntries.filter { !$0.collapsed }
            let collapsedEntries = availableEntries.filter(\.collapsed)

            for entry in directEntries {
                menu.addItem(createOpenMenuItem(for: entry, targets: targets, isContainer: isContainer))
            }

            if !collapsedEntries.isEmpty {
                let openSubmenuItem = NSMenuItem(title: "打开方式", action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: "Open With")
                for entry in collapsedEntries {
                    submenu.addItem(createOpenMenuItem(for: entry, targets: targets, isContainer: isContainer))
                }
                openSubmenuItem.submenu = submenu
                menu.addItem(openSubmenuItem)
            }
        }

        // 分割线
        if menu.numberOfItems > 0 && (settings.showCopyAbsolutePath || settings.showCopyRelativePath || settings.showCopyFileName) {
            menu.addItem(NSMenuItem.separator())
        }

        // 2. 复制类菜单项
        if settings.showCopyAbsolutePath {
            let title = isContainer ? "复制当前目录路径" : "复制绝对路径"
            let item = NSMenuItem(title: title, action: #selector(handleMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = registerAction { [weak self] in
                let paths = targets.map(\.path).joined(separator: "\n")
                self?.copyToPasteboard(paths)
            }
            if let icon = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil) {
                item.image = icon
            }
            menu.addItem(item)
        }

        if !isContainer && settings.showCopyRelativePath {
            let item = NSMenuItem(title: "复制相对路径", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = registerAction { [weak self] in
                guard let self else { return }
                let base = FIFinderSyncController.default().targetedURL()
                let paths = targets.map { url -> String in
                    if let base { return self.relativePath(of: url, to: base) } else { return url.path }
                }.joined(separator: "\n")
                self.copyToPasteboard(paths)
            }
            menu.addItem(item)
        }

        if !isContainer && settings.showCopyFileName {
            let item = NSMenuItem(title: "复制文件名", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = registerAction { [weak self] in
                let names = targets.map(\.lastPathComponent).joined(separator: "\n")
                self?.copyToPasteboard(names)
            }
            menu.addItem(item)
        }

        // 3. 新建文件（仅在有配置启用的文件类型时显示）
        if let dir = targetDirectory {
            addNewFileSubmenuIfNeeded(to: menu, directory: dir)
        }
    }

    /// 创建一个带动作的打开菜单项
    private func createOpenMenuItem(for entry: AppEntry, targets: [URL], isContainer: Bool) -> NSMenuItem {
        let title: String
        if isContainer {
            title = "在 \(entry.name) 中打开此目录"
        } else {
            title = entry.collapsed ? entry.name : "进入 \(entry.name)"
        }

        let item = NSMenuItem(title: title, action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        item.target = self
        item.tag = registerAction { [weak self] in
            for target in targets {
                self?.openWith(appPath: entry.appPath, targetPath: target.path)
            }
        }

        // 加载图标
        let icon = NSWorkspace.shared.icon(forFile: entry.appPath)
        icon.size = NSSize(width: 16, height: 16)
        item.image = icon

        return item
    }

    /// 获取适用于当前目标的应用列表（优先用户配置，若用户配置为空则自动探测本机 VS Code/Cursor/Trae/iTerm）
    private func resolveAvailableEntries(for targets: [URL], isContainer: Bool) -> [AppEntry] {
        let configured = SharedStore.loadEntries()
        var matched = configured.filter { entry in
            if isContainer {
                return !entry.foldersOnly || entry.allowedExtensions.isEmpty
            }
            return targets.allSatisfy { entry.matches(url: $0) }
        }

        // 零失败硬核保底：若没有任何配置匹配，自动探测本机的常用开发工具，永不让菜单落空！
        if matched.isEmpty {
            matched = detectDefaultDeveloperApps(isContainer: isContainer)
        }

        return matched
    }

    /// 自动探测本机的 VS Code/Cursor/Trae/iTerm/终端
    private func detectDefaultDeveloperApps(isContainer: Bool) -> [AppEntry] {
        var results: [AppEntry] = []
        let fm = FileManager.default

        // 1. 探测编辑器 (VS Code, Cursor, Trae)
        let editorCandidates = [
            ("Cursor", "/Applications/Cursor.app"),
            ("Trae CN", "/Applications/Trae CN.app"),
            ("Visual Studio Code", "/Applications/Visual Studio Code.app"),
            ("Trae", "/Applications/Trae.app"),
            ("VS Code Insiders", "/Applications/Visual Studio Code - Insiders.app")
        ]
        for (name, path) in editorCandidates {
            if fm.fileExists(atPath: path) {
                results.append(AppEntry(
                    id: "default-editor-\(name)",
                    name: name,
                    appPath: path,
                    allowedExtensions: [],
                    foldersOnly: false,
                    collapsed: false
                ))
                break // 优先取安装的一个主流编辑器
            }
        }

        // 2. 探测终端 (iTerm 2, iTerm, 系统终端)
        let terminalCandidates = [
            ("iTerm 2", "/Applications/iTerm 2.app"),
            ("iTerm", "/Applications/iTerm.app"),
            ("终端", "/System/Applications/Utilities/Terminal.app")
        ]
        for (name, path) in terminalCandidates {
            if fm.fileExists(atPath: path) {
                results.append(AppEntry(
                    id: "default-terminal-\(name)",
                    name: name,
                    appPath: path,
                    allowedExtensions: [],
                    foldersOnly: false,
                    collapsed: false
                ))
                break // 优先取一个最好用的终端
            }
        }

        return results
    }

    /// 打开目标应用
    private func openWith(appPath: String, targetPath: String) {
        guard var comps = URLComponents(string: "flicker://open") else { return }
        comps.queryItems = [
            URLQueryItem(name: "target", value: targetPath),
            URLQueryItem(name: "app", value: appPath)
        ]
        guard let url = comps.url else { return }
        openContainerApp(with: url)
    }

    /// 新建文件子菜单
    private func addNewFileSubmenuIfNeeded(to menu: NSMenu, directory: String) {
        let newFileSettings = SharedStore.loadNewFileSettings()
        let enabledTypes = NewFileType.defaults.filter { newFileSettings.enabledTypes.contains($0.id) }
        guard !enabledTypes.isEmpty else { return }

        let newFileItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        let newFileSubmenu = NSMenu(title: "New File")
        for fileType in enabledTypes {
            let item = NSMenuItem(
                title: "\(fileType.name) (.\(fileType.ext))",
                action: #selector(handleMenuAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = registerAction { [weak self] in
                self?.proceedWithNewFile(type: fileType.id, path: directory)
            }
            if let icon = NSImage(systemSymbolName: fileType.icon, accessibilityDescription: nil) {
                item.image = icon
            }
            newFileSubmenu.addItem(item)
        }
        newFileItem.submenu = newFileSubmenu
        menu.addItem(newFileItem)
    }

    private func proceedWithNewFile(type: String, path: String) {
        guard var comps = URLComponents(string: "flicker://newfile") else { return }
        comps.queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "path", value: path)
        ]
        guard let url = comps.url else { return }
        openContainerApp(with: url)
    }

    // MARK: - Helpers

    private func getTargetDirectory(for url: URL) -> String? {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), let isDir = values.isDirectory, isDir {
            return url.path
        }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
            return url.path
        }
        if url.hasDirectoryPath {
            return url.path
        }
        return url.deletingLastPathComponent().path
    }

    private func relativePath(of target: URL, to base: URL) -> String {
        let baseComps = base.standardizedFileURL.pathComponents
        let targetComps = target.standardizedFileURL.pathComponents
        var i = 0
        while i < baseComps.count - 1, i < targetComps.count - 1, baseComps[i] == targetComps[i] {
            i += 1
        }
        let ups = max(0, baseComps.count - 1 - i)
        let downs = Array(targetComps.dropFirst(i))
        var parts: [String] = Array(repeating: "..", count: ups)
        parts.append(contentsOf: downs)
        return parts.isEmpty ? "." : parts.joined(separator: "/")
    }

    private func copyToPasteboard(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    private func openContainerApp(with url: URL) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.wangyanan.flicker") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, error in
                if let error {
                    Log.error("open container app failed: \(error.localizedDescription)")
                }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
