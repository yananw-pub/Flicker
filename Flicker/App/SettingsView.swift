//
//  SettingsView.swift
//  Flicker
//
//  DEPRECATED: 功能已拆分到 OpenWithPanel / ActionControlPanel / GeneralSettingsPanel
//  此文件保留作为系统设置窗口的入口，引导用户前往主窗口配置。
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("设置已移至主窗口")
                .font(.title2)
                .fontWeight(.medium)

            Text("请在主窗口左侧导航栏中选择「通用设置」或「操作控制」进行配置。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("打开主窗口") {
                AppActions.shared.openMainWindow?()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 400, height: 300)
        .navigationTitle("设置")
    }
}

#Preview {
    SettingsView()
}
