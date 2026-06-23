//
//  ContentView.swift
//  Flicker
//
//  Main configuration UI: list of configured apps, add/edit, enable-extension help.
//

import SwiftUI
import AppKit
import FinderSync

struct ContentView: View {
    @EnvironmentObject private var store: AppEntryStore
    @Environment(\.openSettings) private var openSettings
    @State private var showingAddSheet = false
    @State private var showingAbout = false
    @State private var editing: AppEntry?

    var body: some View {
        VStack(spacing: 0) {
            listSection
            Divider()
            bottomBar
        }
        .sheet(item: $editing) { entry in
            AppEntryEditor(mode: .edit(entry)) { result in
                if let result { store.update(result) }
                editing = nil
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AppEntryEditor(mode: .add) { result in
                if let result { store.add(result) }
                showingAddSheet = false
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .background(SettingsOpener())
    }

    private var listSection: some View {
        Group {
            if store.entries.isEmpty {
                ContentUnavailableView {
                    Label("暂无配置", systemImage: "square.dashed")
                } description: {
                    Text("点击右下角 + 添加要用右键打开文件的应用")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.entries) { entry in
                        AppEntryRow(entry: entry) {
                            editing = entry
                        }
                        .contextMenu {
                            Button("编辑") { editing = entry }
                            Button("删除", role: .destructive) { store.delete(entry) }
                        }
                    }
                    .onDelete { store.delete(at: $0) }
                    .onMove { store.move(from: $0, to: $1) }
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button {
                FIFinderSyncController.showExtensionManagementInterface()
            } label: {
                Label("启用 Finder 扩展…", systemImage: "puzzlepiece.extension")
            }
            .help("打开系统设置中的「访达扩展」开关，勾选 Flicker")

            Button {
                openSettings()
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            .help("打开设置")

            Button {
                showingAbout = true
            } label: {
                Label("关于", systemImage: "info.circle")
            }
            .help("关于 Flicker")

            Spacer()

            Button {
                showingAddSheet = true
            } label: {
                Label("添加", systemImage: "plus")
            }
            .keyboardShortcut("n")
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }
}

private struct AppEntryRow: View {
    let entry: AppEntry
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            appIcon
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.headline)
                Text(entry.appPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                extText
            }
            Spacer()
            Button("编辑", action: onEdit).buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let nsImage = NSWorkspace.shared.icon(forFile: entry.appPath) as NSImage? {
            Image(nsImage: nsImage).resizable().scaledToFit()
        } else {
            Image(systemName: "app")
        }
    }

    private var extText: some View {
        HStack(spacing: 6) {
            if entry.foldersOnly {
                Text("仅文件夹")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            if entry.foldersOnly {
                Text("不在文件上显示").foregroundStyle(.tertiary)
            } else if entry.allowedExtensions.isEmpty {
                Text("适用所有文件 / 文件夹")
            } else {
                Text(entry.allowedExtensions.joined(separator: ", "))
                    .font(.caption.monospaced())
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}

/// 监听菜单栏"设置…"通知，调用 SwiftUI openSettings 打开设置窗口。
private struct SettingsOpener: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                openSettings()
            }
    }
}
