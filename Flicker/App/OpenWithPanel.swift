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
    @State private var pendingDelete: AppEntry?
    @State private var showingRepairAlert = false
    @State private var repairAlertMessage = ""
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
        .confirmationDialog(
            "删除打开方式？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let entry = pendingDelete {
                Button("删除 \(entry.name)", role: .destructive) {
                    store.delete(entry)
                    pendingDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            if let entry = pendingDelete {
                Text("删除后，\(entry.name) 将不再出现在 Finder 右键菜单中。")
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
                        } onDelete: {
                            pendingDelete = entry
                        }
                        .contextMenu {
                            Button("编辑") { editing = entry }
                            Button("删除", role: .destructive) { pendingDelete = entry }
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
                Label("管理 Finder 扩展…", systemImage: "puzzlepiece.extension")
            }
            .help("打开系统设置中的「访达扩展」开关，管理 Flicker 的系统扩展状态")

            Button {
                let ok = FinderExtensionRegistrar.reregisterEmbeddedExtension()
                if ok {
                    FinderExtensionRegistrar.restartFinder()
                }
                var msg = ok
                    ? "已重新注册本机 Flicker 扩展并刷新访达。请在访达中右键任意文件测试菜单。"
                    : "重新注册失败。请到「系统设置 → 隐私与安全性 → 扩展 → 访达」手动开启 Flicker。"
                if FinderExtensionRegistrar.isAppTranslocated {
                    msg += "\n\n提示：检测到当前应用处于临时隔离环境，请将 Flicker.app 移动至「应用程序」(/Applications) 目录后运行，以确保系统访达扩展稳定加载。"
                }
                repairAlertMessage = msg
                showingRepairAlert = true
            } label: {
                Label("修复扩展注册", systemImage: "arrow.triangle.2.circlepath")
            }
            .help("当本地存在多份 Flicker 构建导致菜单消失时，重新注册当前 App 内的扩展")

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
        .alert("扩展注册", isPresented: $showingRepairAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(repairAlertMessage)
        }
    }
}

/// 应用条目行视图
private struct AppEntryRow: View {
    let entry: AppEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

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
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("编辑")
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("删除")
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
            Text(entry.collapsed ? "打开方式菜单内" : "右键一级菜单")
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(entry.collapsed ? Color.secondary.opacity(0.12) : Color.accentColor.opacity(0.15), in: Capsule())
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
