//
//  SharedStore.swift
//  Flicker
//
//  Shared between the container app and the Finder Sync extension.
//  Reads/writes the configured AppEntry list via a fixed file path.
//

import Foundation
import os

/// 配置读写。App 与扩展共享同一套 JSON。
///
/// 具备高健壮性双路径容灾策略：
/// 1. 扩展沙盒容器路径：`~/Library/Containers/com.wangyanan.flicker.extension/Data/Library/Application Support/Flicker/`
/// 2. 系统通用路径：`~/Library/Application Support/Flicker/`
///
/// 保存时双向写入并广播 `configChanged` 分布式通知；
/// 读取时优先读取容器路径，失败时自动 fallback 到通用路径，确保扩展在沙盒内外均能稳定读取最新设置。
enum SharedStore {
    static let configFileName = "app_entries.json"
    static let menuSettingsFileName = "menu_settings.json"
    static let newFileSettingsFileName = "new_file_settings.json"
    static let appSupportSubdir = "Flicker"
    static let extensionBundleID = "com.wangyanan.flicker.extension"
    static let configChangedNotification = Notification.Name("com.wangyanan.flicker.configChanged")

    private static let logger = Logger(subsystem: "com.wangyanan.flicker", category: "SharedStore")
    nonisolated(unsafe) private static var didMigrateLegacy = false

    /// 判断当前是否处于沙盒进程。
    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// 真实用户主目录（通过 getpwuid 获知真实 ~，不受沙盒重定向影响）。
    private static var realHomeDirectory: URL? {
        guard let pw = getpwuid(getuid()) else { return nil }
        return URL(fileURLWithFileSystemRepresentation: pw.pointee.pw_dir, isDirectory: true, relativeTo: nil)
    }

    private static func ensureDirectory(_ dir: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// 系统通用 Application Support/Flicker 目录。
    static var standardDirectoryURL: URL? {
        guard let home = realHomeDirectory else { return nil }
        let dir = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(appSupportSubdir, isDirectory: true)
        ensureDirectory(dir)
        return dir
    }

    /// 扩展 Container 内的 Application Support/Flicker 目录。
    static var containerDirectoryURL: URL? {
        if isSandboxed {
            // 在扩展沙盒进程中：系统已将 Application Support 映射到其容器内。
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dir = appSupport.appendingPathComponent(appSupportSubdir, isDirectory: true)
                ensureDirectory(dir)
                return dir
            }
        }

        // 主 App 或非沙盒环境：直接通过真实路径访问扩展 Container。
        guard let home = realHomeDirectory else { return nil }
        let dir = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent(extensionBundleID, isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(appSupportSubdir, isDirectory: true)
        ensureDirectory(dir)
        return dir
    }

    /// 仅由主应用调用的历史文件单向迁移。
    static func migrateLegacyIfNeeded() {
        guard !isSandboxed else { return } // 沙盒内不执行跨目录拷贝，避免报权限错误
        guard !didMigrateLegacy else { return }
        didMigrateLegacy = true

        guard let legacy = standardDirectoryURL, let target = containerDirectoryURL else { return }
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacy.path) else { return }

        let names = [configFileName, menuSettingsFileName, newFileSettingsFileName]
        for name in names {
            let src = legacy.appendingPathComponent(name, isDirectory: false)
            let dst = target.appendingPathComponent(name, isDirectory: false)
            guard fm.fileExists(atPath: src.path) else { continue }
            if fm.fileExists(atPath: dst.path) {
                if let srcDate = (try? src.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                   let dstDate = (try? dst.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                   dstDate >= srcDate {
                    continue
                }
                try? fm.removeItem(at: dst)
            }
            try? fm.copyItem(at: src, to: dst)
        }
    }

    /// 广播配置变更通知，通知扩展与 Finder 立即更新缓存。
    static func notifyConfigChanged() {
        DistributedNotificationCenter.default().postNotificationName(
            configChangedNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    /// 双路径容灾读取：先读取首选路径，失败则回退到备用路径。
    private static func readData(fileName: String) -> Data? {
        var candidateURLs: [URL] = []
        if let containerURL = containerDirectoryURL?.appendingPathComponent(fileName, isDirectory: false) {
            candidateURLs.append(containerURL)
        }
        if let standardURL = standardDirectoryURL?.appendingPathComponent(fileName, isDirectory: false) {
            candidateURLs.append(standardURL)
        }

        for url in candidateURLs {
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    /// 双路径安全写入：同时写入容器路径与通用路径。
    private static func writeData(_ data: Data, fileName: String) -> Bool {
        var success = false
        var targetURLs: [URL] = []
        if let containerDir = containerDirectoryURL {
            targetURLs.append(containerDir.appendingPathComponent(fileName, isDirectory: false))
        }
        if let standardDir = standardDirectoryURL {
            targetURLs.append(standardDir.appendingPathComponent(fileName, isDirectory: false))
        }

        for url in targetURLs {
            do {
                try data.write(to: url, options: .atomic)
                success = true
            } catch {
                logger.error("writeData to \(url.path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        if success {
            notifyConfigChanged()
        }
        return success
    }

    // MARK: - App Entries

    static func loadEntries() -> [AppEntry] {
        guard let data = readData(fileName: configFileName) else { return [] }
        do {
            return try JSONDecoder().decode([AppEntry].self, from: data)
        } catch {
            logger.error("loadEntries decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    @discardableResult
    static func saveEntries(_ entries: [AppEntry]) -> Bool {
        do {
            let data = try JSONEncoder().encode(entries)
            return writeData(data, fileName: configFileName)
        } catch {
            logger.error("saveEntries encode failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Menu Settings

    static func loadMenuSettings() -> MenuSettings {
        guard let data = readData(fileName: menuSettingsFileName) else { return .defaults }
        do {
            return try JSONDecoder().decode(MenuSettings.self, from: data)
        } catch {
            logger.error("loadMenuSettings decode failed: \(error.localizedDescription, privacy: .public)")
            return .defaults
        }
    }

    @discardableResult
    static func saveMenuSettings(_ settings: MenuSettings) -> Bool {
        do {
            let data = try JSONEncoder().encode(settings)
            return writeData(data, fileName: menuSettingsFileName)
        } catch {
            logger.error("saveMenuSettings encode failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - New File Settings

    static func loadNewFileSettings() -> NewFileSettings {
        guard let data = readData(fileName: newFileSettingsFileName) else { return .defaults }
        do {
            return try JSONDecoder().decode(NewFileSettings.self, from: data)
        } catch {
            logger.error("loadNewFileSettings decode failed: \(error.localizedDescription, privacy: .public)")
            return .defaults
        }
    }

    @discardableResult
    static func saveNewFileSettings(_ settings: NewFileSettings) -> Bool {
        do {
            let data = try JSONEncoder().encode(settings)
            return writeData(data, fileName: newFileSettingsFileName)
        } catch {
            logger.error("saveNewFileSettings encode failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 主应用启动时自动补齐缺失的基础配置文件。
    static func ensureInitialConfigsExist() {
        guard !isSandboxed else { return }
        migrateLegacyIfNeeded()

        if readData(fileName: menuSettingsFileName) == nil {
            saveMenuSettings(.defaults)
        }
        if readData(fileName: newFileSettingsFileName) == nil {
            saveNewFileSettings(.defaults)
        }
    }
}
