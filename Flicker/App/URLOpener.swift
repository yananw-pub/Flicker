//
//  URLOpener.swift
//  Flicker
//
//  Handles custom URL scheme `flicker://` invoked by the Finder extension.
//
//  背景：Finder Sync 扩展运行在沙箱内，直接调用
//  `NSWorkspace.shared.open([target], withApplicationAt:)` 会被系统拦截，
//  报“应用程序 Flicker 没有权限打开 xxx”。因此扩展改为通过 URL scheme
//  把目标文件与应用路径交给非沙箱的容器 App，由容器 App 真正执行打开。
//

import AppKit

enum URLOpener {
    static let scheme = "flicker"

    /// 处理 `flicker://open?target=<路径>&app=<路径>` 和 `flicker://newfile?type=<类型>&path=<目录路径>`。
    static func handle(_ url: URL) {
        Log.debug("URLOpener.handle called with url: \(url)")
        guard url.scheme?.lowercased() == scheme else {
            Log.debug("invalid scheme: \(url.scheme ?? "nil")")
            return
        }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Log.error("failed to parse URLComponents")
            return
        }
        
        Log.debug("host=\(comps.host ?? "nil")")
        
        switch comps.host?.lowercased() {
        case "open":
            handleOpen(comps)
        case "newfile":
            handleNewFile(comps)
        default:
            Log.debug("unknown host: \(comps.host ?? "nil")")
            return
        }
    }
    
    /// 处理 `flicker://open?target=<路径>&app=<路径>`。
    private static func handleOpen(_ comps: URLComponents) {
        let targetPath = comps.queryItems?.first(where: { $0.name == "target" })?.value?
            .removingPercentEncoding
        let appPath = comps.queryItems?.first(where: { $0.name == "app" })?.value?
            .removingPercentEncoding
        guard let targetPath, let appPath else { return }

        let targetURL = URL(fileURLWithPath: targetPath)
        let appURL = URL(fileURLWithPath: appPath)

        // 容器 App 非沙盒，可自由用任意应用打开任意文件。
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false   // 不要激活目标应用的窗口
        NSWorkspace.shared.open([targetURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error {
                Log.error("open via container failed: \(error.localizedDescription)")
            }
        }

        hideApp()
    }
    
    /// 处理 `flicker://newfile?type=<类型>&path=<目录路径>`。
    private static func handleNewFile(_ comps: URLComponents) {
        Log.debug("handleNewFile called")
        
        let type = comps.queryItems?.first(where: { $0.name == "type" })?.value
        let path = comps.queryItems?.first(where: { $0.name == "path" })?.value?.removingPercentEncoding
        
        Log.debug("type=\(type ?? "nil"), path=\(path ?? "nil")")
        
        guard let type, let path else {
            Log.error("missing type or path")
            return
        }
        
        // 查找文件类型
        guard let fileType = NewFileType.defaults.first(where: { $0.id == type }) else {
            Log.error("unknown file type: \(type)")
            return
        }
        
        Log.debug("fileType=\(fileType.name), ext=\(fileType.ext)")
        
        // 创建文件
        let fileURL = createNewFile(fileType: fileType, directory: path)
        
        // 根据设置决定是否自动打开
        let settings = SharedStore.loadNewFileSettings()
        Log.debug("autoOpen=\(settings.autoOpen), fileURL=\(fileURL?.path ?? "nil")")
        
        if settings.autoOpen, let fileURL {
            Log.debug("opening file: \(fileURL.path)")
            NSWorkspace.shared.open(fileURL)
        }
        
        hideApp()
    }
    
    /// 创建新文件，处理重名冲突。
    private static func createNewFile(fileType: NewFileType, directory: String) -> URL? {
        Log.debug("createNewFile: directory=\(directory), ext=\(fileType.ext)")
        
        let baseURL = URL(fileURLWithPath: directory)
        var fileName = "新建文件.\(fileType.ext)"
        var fileURL = baseURL.appendingPathComponent(fileName)
        
        Log.debug("initial fileURL=\(fileURL.path)")
        
        // 检查目录是否存在
        var isDir: ObjCBool = false
        let dirExists = FileManager.default.fileExists(atPath: directory, isDirectory: &isDir)
        Log.debug("directory exists=\(dirExists), isDir=\(isDir.boolValue)")
        
        if !dirExists {
            Log.error("directory does not exist!")
            return nil
        }
        
        // 处理重名：添加数字后缀
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileName = "新建文件 \(counter).\(fileType.ext)"
            fileURL = baseURL.appendingPathComponent(fileName)
            counter += 1
        }
        
        Log.debug("final fileURL=\(fileURL.path)")
        
        // 创建空文件
        let success = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        if success {
            Log.debug("SUCCESS created file: \(fileURL.path)")
            return fileURL
        } else {
            Log.error("FAILED to create file: \(fileURL.path)")
            let dirWritable = FileManager.default.isWritableFile(atPath: directory)
            Log.error("directory writable=\(dirWritable)")
            return nil
        }
    }
    
    /// 隐藏应用，避免主窗口抢占焦点。
    private static func hideApp() {
        if AppDelegate.launchedByURL {
            // 冷启动场景：保持 accessory 策略，隐藏残留窗口。
            NSApp.windows.forEach { $0.orderOut(nil) }
        } else {
            // 已在运行的场景：隐藏整个应用，让用户继续留在 Finder。
            NSApp.hide(nil)
        }
    }
}
