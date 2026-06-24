//
//  ActionControlPanel.swift
//  Flicker
//
//  "操作控制"配置面板，管理右键菜单项开关和新建文件设置。
//

import SwiftUI

struct ActionControlPanel: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("右键菜单") {
                Toggle("复制绝对路径", isOn: $settings.showCopyAbsolutePath)
                    .help("在右键菜单中显示「复制绝对路径」")
                Toggle("复制相对路径", isOn: $settings.showCopyRelativePath)
                    .help("在右键菜单中显示「复制相对路径」")
                Toggle("复制文件名", isOn: $settings.showCopyFileName)
                    .help("在右键菜单中显示「复制文件名」")
            }
            Section("新建文件") {
                ForEach(NewFileType.defaults) { fileType in
                    Toggle(fileType.name + " (." + fileType.ext + ")", isOn: Binding(
                        get: { settings.newFileEnabledTypes.contains(fileType.id) },
                        set: { enabled in
                            if enabled {
                                if !settings.newFileEnabledTypes.contains(fileType.id) {
                                    settings.newFileEnabledTypes.append(fileType.id)
                                }
                            } else {
                                settings.newFileEnabledTypes.removeAll { $0 == fileType.id }
                            }
                        }
                    ))
                    .help("在右键菜单中显示新建「\(fileType.name)」选项")
                }
                Toggle("创建后自动打开", isOn: $settings.newFileAutoOpen)
                    .help("新建文件后自动用默认应用打开")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    ActionControlPanel()
}
