//
//  FinderExtensionRegistrar.swift
//  Flicker
//
//  确保本 App 内嵌的 Finder Sync 扩展被系统识别并启用。
//  多次本地/CI 构建会在 /tmp 等路径留下副本，pkd 可能优先加载旧副本导致菜单消失。
//

import Foundation
import os

enum FinderExtensionRegistrar {
    private static let logger = Logger(subsystem: "com.wangyanan.flicker", category: "ExtensionRegistrar")
    static let extensionBundleID = "com.wangyanan.flicker.extension"

    /// 当前运行中的 App 内嵌 appex 路径。
    static var embeddedExtensionURL: URL? {
        Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("FlickerExtension.appex", isDirectory: true)
    }

    /// 启动时：确保基础配置存在 + 注册/启用本包内的扩展。
    static func prepareOnLaunch() {
        SharedStore.ensureInitialConfigsExist()
        reregisterEmbeddedExtension()
    }

    /// 当前应用是否处于 App Translocation 隔离环境下运行。
    static var isAppTranslocated: Bool {
        Bundle.main.bundlePath.contains("/AppTranslocation/")
    }

    /// 重新向 pluginkit 注册本包扩展并设为启用。
    @discardableResult
    static func reregisterEmbeddedExtension() -> Bool {
        guard let url = embeddedExtensionURL, FileManager.default.fileExists(atPath: url.path) else {
            logger.error("embedded FlickerExtension.appex not found")
            return false
        }
        let path = url.path

        // 1. 先清除历史选举冲突
        _ = runPluginKit(arguments: ["-e", "ignore", "-i", extensionBundleID])
        // 2. 添加本包扩展
        let addOK = runPluginKit(arguments: ["-a", path])
        // 3. 用户选举启用
        let useOK = runPluginKit(arguments: ["-e", "use", "-i", extensionBundleID])
        // 4. 同步登记到 LaunchServices
        _ = runLsregister(arguments: ["-f", "-R", "-trusted", path])

        logger.info("reregister appex add=\(addOK, privacy: .public) use=\(useOK, privacy: .public) path=\(path, privacy: .public)")

        // 5. 重启扩展常驻进程，确保加载当前最新二进制与配置
        reloadExtensionProcess()

        return addOK && useOK
    }

    /// 重启 Finder（用于用户点击修复时确保访达重新载入扩展）
    static func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    /// 终止当前驻留的 FlickerExtension 扩展进程（系统会在下次右键时自动拉起最新进程）。
    static func reloadExtensionProcess() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["FlickerExtension"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private static func runLsregister(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func runPluginKit(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            logger.error("pluginkit \(arguments.joined(separator: " "), privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
