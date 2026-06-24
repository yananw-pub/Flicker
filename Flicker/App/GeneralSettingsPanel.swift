//
//  GeneralSettingsPanel.swift
//  Flicker
//
//  "通用设置"配置面板，管理界面和启动相关设置。
//

import SwiftUI

struct GeneralSettingsPanel: View {
    @ObservedObject private var settings = AppSettings.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        Form {
            Section("界面") {
                Toggle("在系统菜单栏显示图标", isOn: $settings.showMenuBarIcon)
                    .help("关闭后将从菜单栏移除 Flicker 图标")
                Toggle("在Dock栏显示", isOn: $settings.showInDock)
                    .help("关闭后应用将作为菜单栏/后台应用运行")
            }
            Section("启动") {
                Toggle("开机时自动启动", isOn: $settings.launchAtLogin)
                    .help("登录 macOS 时自动运行 Flicker")
            }
            Section("更新") {
                Toggle("启动时自动检查更新", isOn: $settings.autoCheckUpdates)
                    .help("应用启动后静默检查 GitHub Releases 是否有新版本")
                Button("立即检查更新…") {
                    UpdateChecker.checkManually()
                }
            }
            Section("关于 Flicker") {
                HStack(spacing: 14) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flicker")
                            .font(.headline)
                        Text("版本 \(appVersion) (\(buildNumber))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Text("极简 macOS Finder 右键菜单扩展，提升文件操作效率。")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Link(destination: URL(string: "https://github.com/yananw-pub/Flicker")!) {
                    Label("GitHub 仓库", systemImage: "link")
                }
                Link(destination: URL(string: "https://github.com/yananw-pub/Flicker/issues")!) {
                    Label("反馈问题", systemImage: "exclamationmark.bubble")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Copyright © 2026 wangyanan")
                    Text("MIT License")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    GeneralSettingsPanel()
}
