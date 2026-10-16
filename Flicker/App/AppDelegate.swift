//
//  AppDelegate.swift
//  Flicker
//
//  管理 URL 启动检测、窗口复用策略，并按用户设置应用
//  程序坞 / 菜单栏 / 开机自启动。
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 是否因处理自定义 URL 而被拉起（扩展触发"打开方式"）。
    /// 仅在主线程读写。
    nonisolated(unsafe) static var launchedByURL = false
    nonisolated(unsafe) private static weak var sharedInstance: AppDelegate?

    static let showMainWindowNotification = Notification.Name("com.wangyanan.flicker.showMainWindow")
    static let handleURLNotification = Notification.Name("com.wangyanan.flicker.handleURL")

    func applicationWillFinishLaunching(_ notification: Notification) {
        Self.sharedInstance = self

        // 通过 URL 启动时，系统会带上 kAEGetURL Apple Event，direct object 即 URL 字符串。
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchURLString = event?.paramDescriptor(forKeyword: keyDirectObject)?.stringValue
        let isURLTriggered = launchURLString?.lowercased().hasPrefix("\(URLOpener.scheme)://") ?? false
        if isURLTriggered {
            Self.launchedByURL = true
        }

        // 单实例检查：检测是否已有其他 Flicker 实例在运行
        let bundleID = Bundle.main.bundleIdentifier ?? "com.wangyanan.flicker"
        let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        if let existingApp = otherInstances.first {
            if isURLTriggered, let launchURLString {
                // 转发 URL 请求至已有实例
                DistributedNotificationCenter.default().postNotificationName(
                    Self.handleURLNotification,
                    object: nil,
                    userInfo: ["url": launchURLString],
                    deliverImmediately: true
                )
            } else {
                // 唤醒已有实例并展示主窗口
                DistributedNotificationCenter.default().postNotificationName(
                    Self.showMainWindowNotification,
                    object: nil,
                    userInfo: nil,
                    deliverImmediately: true
                )
                existingApp.activate()
            }
            // 立即退出重复的新实例，确保全局唯一进程
            exit(0)
        }

        // 注册分布式通知监听（供后续多开或转发时唤醒本进程）
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowMainWindowNotification(_:)),
            name: Self.showMainWindowNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleExternalURLNotification(_:)),
            name: Self.handleURLNotification,
            object: nil
        )

        if Self.launchedByURL {
            // 扩展拉起时保持静默：不抢焦点、不显窗口。
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 配置迁到扩展 Container，并确保本包 Finder Sync 扩展被系统启用。
        FinderExtensionRegistrar.prepareOnLaunch()

        if Self.launchedByURL {
            // 静默运行：隐藏窗口，不应用界面设置，仅同步登录项。
            NSApp.windows.forEach { $0.orderOut(nil) }
            AppSettings.shared.applyLoginItem()
        } else {
            AppSettings.shared.applyAll()
            // 延迟 3 秒后静默检查更新，不阻塞启动。
            Task {
                try? await Task.sleep(for: .seconds(3))
                UpdateChecker.checkAndNotify()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 用户再次打开已运行的应用（如从 Dock / Finder 点击）：显示主窗口并应用界面设置。
        showMainWindow()
        AppSettings.shared.applyAll()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 有菜单栏图标时保留进程（可随时重新打开窗口）；否则关闭即退出。
        return !AppSettings.shared.showMenuBarIcon
    }

    @MainActor @objc func showMainWindow() {
        AppActions.shared.openMainWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - URL Handling
    
    func application(_ application: NSApplication, open urls: [URL]) {
        Log.debug("application open urls: \(urls)")
        for url in urls {
            URLOpener.handle(url)
        }
    }

    func application(_ application: NSApplication, open url: URL) -> Bool {
        Log.debug("application open url: \(url)")
        URLOpener.handle(url)
        return true
    }

    // MARK: - Distributed Notification Handlers

    @objc nonisolated private func handleShowMainWindowNotification(_ notification: Notification) {
        Task { @MainActor in
            Self.sharedInstance?.showMainWindow()
            AppSettings.shared.applyAll()
        }
    }

    @objc nonisolated private func handleExternalURLNotification(_ notification: Notification) {
        guard let urlString = notification.userInfo?["url"] as? String,
              let url = URL(string: urlString) else { return }
        Task { @MainActor in
            URLOpener.handle(url)
        }
    }
}
