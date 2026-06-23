//
//  AboutView.swift
//  Flicker
//
//  关于页面：展示应用概览信息。
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 24) {
            appIconSection
            infoSection
            linksSection
            copyrightSection
            Spacer()
            doneButton
        }
        .padding(32)
        .frame(width: 360, height: 440)
    }

    private var appIconSection: some View {
        Group {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
            } else {
                Image(systemName: "contextualmenu.and.cursorarrow")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var infoSection: some View {
        VStack(spacing: 6) {
            Text("Flicker")
                .font(.system(size: 24, weight: .semibold))
            Text("版本 \(appVersion) (\(buildNumber))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("极简 macOS Finder 右键菜单扩展，\n提升文件操作效率")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    private var linksSection: some View {
        VStack(spacing: 10) {
            Link(destination: URL(string: "https://github.com/yananw-pub/Flicker")!) {
                Label("GitHub 仓库", systemImage: "link")
            }
            Link(destination: URL(string: "https://github.com/yananw-pub/Flicker/issues")!) {
                Label("反馈问题", systemImage: "exclamationmark.bubble")
            }
        }
        .font(.subheadline)
    }

    private var copyrightSection: some View {
        VStack(spacing: 4) {
            Text("Copyright © 2026 wangyanan")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var doneButton: some View {
        Button("完成") {
            dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
    }
}

#Preview {
    AboutView()
}
