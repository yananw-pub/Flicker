//
//  AppMenuBar.swift
//  Flicker
//
//  系统菜单栏图标与菜单。
//

import AppKit

@MainActor
final class AppMenuBar {
    static let shared = AppMenuBar()
    private var statusItem: NSStatusItem?
    private init() {}

    func setVisible(_ visible: Bool) {
        if visible {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                if let icon = NSImage(named: "MenuBarIcon") {
                    icon.isTemplate = true
                    icon.size = NSSize(width: 18, height: 18)
                    button.image = icon
                } else {
                    let symbol = NSImage(systemSymbolName: "contextualmenu.and.cursorarrow",
                                         accessibilityDescription: "Flicker")
                    symbol?.isTemplate = true
                    button.image = symbol
                }
            }
            item.menu = buildMenu()
            statusItem = item
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let showItem = menu.addItem(withTitle: "打开主窗口", action: #selector(showMainWindow), keyEquivalent: "")
        showItem.target = self

        menu.addItem(.separator())

        let settingsItem = menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self

        menu.addItem(.separator())

        let updateItem = menu.addItem(withTitle: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self

        menu.addItem(.separator())

        let quitItem = menu.addItem(withTitle: "退出 Flicker", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

        return menu
    }

    @objc private func showMainWindow() {
        AppActions.shared.openMainWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        AppActions.shared.openSettings?()
    }

    @objc private func checkForUpdates() {
        UpdateChecker.checkManually()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
