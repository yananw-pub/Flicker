//
//  AppSettings.swift
//  Flicker
//
//  用户偏好：菜单栏图标、程序坞、开机自启动。持久化于 UserDefaults；
//  开机自启动用 SMAppService（macOS 13+）。
//

import AppKit
import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let menuBar = "showMenuBarIcon"
        static let dock = "showInDock"
        static let login = "launchAtLogin"
        static let autoUpdate = "autoCheckUpdates"
    }

    private func persistMenuSettings() {
        SharedStore.saveMenuSettings(MenuSettings(
            showCopyAbsolutePath: showCopyAbsolutePath,
            showCopyRelativePath: showCopyRelativePath,
            showCopyFileName: showCopyFileName
        ))
    }
    
    private func persistNewFileSettings() {
        SharedStore.saveNewFileSettings(NewFileSettings(
            enabledTypes: newFileEnabledTypes,
            autoOpen: newFileAutoOpen
        ))
    }

    private let defaults = UserDefaults.standard

    /// 在系统菜单栏显示应用图标。
    @Published var showMenuBarIcon: Bool = true {
        didSet {
            defaults.set(showMenuBarIcon, forKey: Key.menuBar)
            applyMenuBar()
        }
    }
    /// 在程序坞中显示应用。
    @Published var showInDock: Bool = true {
        didSet {
            defaults.set(showInDock, forKey: Key.dock)
            applyDock()
        }
    }
    /// 开机时自动启动。
    @Published var launchAtLogin: Bool = false {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.login)
            applyLoginItem()
        }
    }
    /// 启动时自动检查更新。
    @Published var autoCheckUpdates: Bool = true {
        didSet {
            defaults.set(autoCheckUpdates, forKey: Key.autoUpdate)
        }
    }

    // MARK: - 右键菜单开关（通过 SharedStore 与扩展共享）

    /// 显示「复制绝对路径」。
    @Published var showCopyAbsolutePath: Bool = true {
        didSet { persistMenuSettings() }
    }
    /// 显示「复制相对路径」。
    @Published var showCopyRelativePath: Bool = true {
        didSet { persistMenuSettings() }
    }
    /// 显示「复制文件名」。
    @Published var showCopyFileName: Bool = true {
        didSet { persistMenuSettings() }
    }
    
    // MARK: - 新建文件设置（通过 SharedStore 与扩展共享）
    
    /// 启用的文件类型ID列表。
    @Published var newFileEnabledTypes: [String] = ["txt", "md"] {
        didSet { persistNewFileSettings() }
    }
    /// 创建后自动打开。
    @Published var newFileAutoOpen: Bool = true {
        didSet { persistNewFileSettings() }
    }

    init() {
        showMenuBarIcon = (defaults.object(forKey: Key.menuBar) as? Bool) ?? true
        showInDock = (defaults.object(forKey: Key.dock) as? Bool) ?? true
        launchAtLogin = (defaults.object(forKey: Key.login) as? Bool) ?? false
        autoCheckUpdates = (defaults.object(forKey: Key.autoUpdate) as? Bool) ?? true

        let menuSettings = SharedStore.loadMenuSettings()
        showCopyAbsolutePath = menuSettings.showCopyAbsolutePath
        showCopyRelativePath = menuSettings.showCopyRelativePath
        showCopyFileName = menuSettings.showCopyFileName
        
        let newFileSettings = SharedStore.loadNewFileSettings()
        newFileEnabledTypes = newFileSettings.enabledTypes
        newFileAutoOpen = newFileSettings.autoOpen
    }

    /// 应用全部设置（正常启动或用户重新打开应用时调用）。
    func applyAll() {
        applyDock()
        applyMenuBar()
        applyLoginItem()
    }

    func applyDock() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    func applyMenuBar() {
        AppMenuBar.shared.setVisible(showMenuBarIcon)
    }

    func applyLoginItem() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
        } catch {
            NSLog("[Flicker] login item toggle failed: \(error.localizedDescription)")
        }
    }
}
