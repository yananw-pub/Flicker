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

    override init() {
        super.init()
        // 监视根目录，使右键菜单可出现在任意位置。
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "Flicker")
        
        // 处理空白区域右键（容器菜单）
        if menuKind == .contextualMenuForContainer {
            // 获取当前目录
            if let targetURL = FIFinderSyncController.default().targetedURL() {
                addNewFileMenu(to: menu, directory: targetURL.path)
            }
            return menu
        }

        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForSidebar,
              let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else {
            return menu
        }
        let target = urls[0]

        // Open With 子菜单
        let entries = SharedStore.loadEntries()
        let matched = entries.filter { $0.matches(url: target) }
        if !matched.isEmpty {
            let openItem = NSMenuItem(title: "打开方式", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "Open With")
            for entry in matched {
                let item = NSMenuItem(title: entry.name, action: #selector(openWithApp(_:)), keyEquivalent: "")
                item.target = self
                item.tag = entry.id.hashValue
                item.image = NSWorkspace.shared.icon(forFile: entry.appPath)
                item.image?.size = NSSize(width: 16, height: 16)
                submenu.addItem(item)
            }
            openItem.submenu = submenu
            menu.addItem(openItem)
        }

        // 复制类菜单项（受菜单设置控制）
        let menuSettings = SharedStore.loadMenuSettings()
        if menuSettings.showCopyAbsolutePath {
            menu.addItem(withTitle: "复制绝对路径", action: #selector(copyAbsolutePath(_:)), keyEquivalent: "")
        }
        if menuSettings.showCopyRelativePath {
            menu.addItem(withTitle: "复制相对路径", action: #selector(copyRelativePath(_:)), keyEquivalent: "")
        }
        if menuSettings.showCopyFileName {
            menu.addItem(withTitle: "复制文件名", action: #selector(copyFileName(_:)), keyEquivalent: "")
        }
        
        // 新建文件子菜单（仅在文件夹或文件所在目录显示）
        let directory = getTargetDirectory(for: target)
        if let directory {
            addNewFileMenu(to: menu, directory: directory)
        }

        return menu
    }
    
    /// 添加新建文件子菜单到指定菜单。
    private func addNewFileMenu(to menu: NSMenu, directory: String) {
        let newFileSettings = SharedStore.loadNewFileSettings()
        let enabledTypes = NewFileType.defaults.filter { newFileSettings.enabledTypes.contains($0.id) }
        guard !enabledTypes.isEmpty else { return }
        
        let newFileItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        let newFileSubmenu = NSMenu(title: "New File")
        for fileType in enabledTypes {
            let item = NSMenuItem(
                title: "\(fileType.name) (.\(fileType.ext))",
                action: #selector(createNewFile(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.toolTip = "\(fileType.id)|\(directory)"
            if let icon = NSImage(systemSymbolName: fileType.icon, accessibilityDescription: nil) {
                item.image = icon
            }
            newFileSubmenu.addItem(item)
        }
        newFileItem.submenu = newFileSubmenu
        menu.addItem(newFileItem)
    }
    
    /// 获取目标目录路径（如果是文件夹则返回其路径，否则返回文件所在目录）。
    private func getTargetDirectory(for url: URL) -> String? {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
            return url.path
        }
        return url.deletingLastPathComponent().path
    }

    // MARK: - Actions

    @objc private func openWithApp(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let entries = SharedStore.loadEntries()
        // tag 不可靠地反查 id（hashValue 可能冲突），改用 title 匹配名称。
        guard let entry = entries.first(where: { $0.name == sender.title || $0.id.hashValue == sender.tag }) else { return }

        // 扩展处于沙盒，直接用 NSWorkspace 打开会被系统拦截。
        // 改为通过自定义 URL scheme 拉起非沙盒的容器 App，由其执行打开动作。
        // 多选时逐个发送 URL scheme，由容器 App 依次打开。
        for target in urls {
            guard var comps = URLComponents(string: "flicker://open") else { continue }
            comps.queryItems = [
                URLQueryItem(name: "target", value: target.path),
                URLQueryItem(name: "app", value: entry.appPath)
            ]
            guard let url = comps.url else { continue }
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func copyAbsolutePath(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let paths = urls.map(\.path).joined(separator: "\n")
        copyToPasteboard(paths)
    }

    @objc private func copyRelativePath(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let base = FIFinderSyncController.default().targetedURL()
        let paths = urls.map { url -> String in
            if let base { return relativePath(of: url, to: base) } else { return url.path }
        }.joined(separator: "\n")
        copyToPasteboard(paths)
    }

    @objc private func copyFileName(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let names = urls.map(\.lastPathComponent).joined(separator: "\n")
        copyToPasteboard(names)
    }
    
    @objc private func createNewFile(_ sender: NSMenuItem) {
        Log.debug("createNewFile called")
        Log.debug("title=\(sender.title)")
        Log.debug("toolTip=\(sender.toolTip ?? "nil")")
        Log.debug("tag=\(sender.tag)")
        
        guard let identifier = sender.toolTip,
              let separatorIndex = identifier.firstIndex(of: "|") else {
            Log.debug("missing or invalid toolTip, trying to parse from title")
            // 尝试从 title 中解析文件类型
            let title = sender.title
            if let ext = extractExtension(from: title) {
                Log.debug("extracted ext=\(ext) from title")
                // 使用 targetedURL 获取当前目录
                if let targetURL = FIFinderSyncController.default().targetedURL() {
                    let path = targetURL.path
                    Log.debug("using targetedURL path=\(path)")
                    proceedWithNewFile(type: ext, path: path)
                    return
                }
            }
            Log.error("could not determine file type")
            return
        }
        
        let type = String(identifier[identifier.startIndex..<separatorIndex])
        let path = String(identifier[identifier.index(after: separatorIndex)...])
        
        Log.debug("type=\(type), path=\(path)")
        proceedWithNewFile(type: type, path: path)
    }
    
    /// 从标题中提取文件扩展名，如 "文本文档 (.txt)" -> "txt"
    private func extractExtension(from title: String) -> String? {
        // 查找括号中的扩展名
        guard let start = title.lastIndex(of: "("),
              let end = title.lastIndex(of: ")"),
              start < end else { return nil }
        let extRange = title.index(after: start)..<end
        var ext = String(title[extRange])
        // 移除开头的点
        if ext.hasPrefix(".") {
            ext = String(ext.dropFirst())
        }
        return ext.isEmpty ? nil : ext
    }
    
    /// 通过 URL Scheme 调用容器 App 创建文件
    private func proceedWithNewFile(type: String, path: String) {
        Log.debug("proceedWithNewFile: type=\(type), path=\(path)")
        guard var comps = URLComponents(string: "flicker://newfile") else {
            Log.error("proceedWithNewFile: failed to create URLComponents")
            return
        }
        comps.queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "path", value: path)
        ]
        guard let url = comps.url else {
            Log.error("proceedWithNewFile: failed to create URL")
            return
        }
        Log.debug("proceedWithNewFile: opening URL: \(url)")
        NSWorkspace.shared.open(url)
    }

    // MARK: - Helpers

    /// 计算 target 相对于 base 的路径（如 "sub/file.txt"、"../sibling/file.txt"）。
    /// base 不在 target 的祖先链上时回退为 target 的绝对路径。
    private func relativePath(of target: URL, to base: URL) -> String {
        let baseComps = base.standardizedFileURL.pathComponents
        let targetComps = target.standardizedFileURL.pathComponents
        // 找公共前缀
        var i = 0
        while i < baseComps.count - 1, i < targetComps.count - 1, baseComps[i] == targetComps[i] {
            i += 1
        }
        // base 剩余的每一级都对应一次 ".."
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
}
