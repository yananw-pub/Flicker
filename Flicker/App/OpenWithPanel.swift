//
//  OpenWithPanel.swift
//  Flicker
//
//  "打开方式"配置面板，管理右键菜单中可用的应用列表。
//

import SwiftUI
import FinderSync

struct OpenWithPanel: View {
    @EnvironmentObject private var store: AppEntryStore
    @State private var showingAddSheet = false
    @State private var editing: AppEntry?
    @Environment(\.openSettings) private var openSettings

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
    }

    private var listSection: some View {
        Group {
            if store.entries.isEmpty {
                ContentUnavailableView {
                    Label("暂无配置", systemImage: "square.dashed")
                } description: {
                    Text("点击下方 + 添加要用右键打开文件的应用")
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

/// 应用条目行视图
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

#Preview {
    OpenWithPanel()
        .environmentObject(AppEntryStore())
}
