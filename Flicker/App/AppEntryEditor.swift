//
//  AppEntryEditor.swift
//  Flicker
//
//  Add / edit sheet: pick a .app, set name and applicable extensions.
//

import SwiftUI
import AppKit

struct AppEntryEditor: View {
    enum Mode {
        case add
        case edit(AppEntry)
    }

    let mode: Mode
    let onCommit: (AppEntry?) -> Void

    @State private var name: String = ""
    @State private var appPath: String = ""
    @State private var extText: String = "" // 逗号或空格分隔
    @State private var foldersOnly: Bool = false
    @State private var collapsed: Bool = true
    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, onCommit: @escaping (AppEntry?) -> Void) {
        self.mode = mode
        self.onCommit = onCommit
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _appPath = State(initialValue: "")
            _extText = State(initialValue: "")
            _foldersOnly = State(initialValue: false)
            _collapsed = State(initialValue: true)
        case .edit(let e):
            _name = State(initialValue: e.name)
            _appPath = State(initialValue: e.appPath)
            _extText = State(initialValue: e.allowedExtensions.joined(separator: ", "))
            _foldersOnly = State(initialValue: e.foldersOnly)
            _collapsed = State(initialValue: e.collapsed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(modeTitle).font(.headline)

            HStack(spacing: 12) {
                previewIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text("应用程序").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(appPath.isEmpty ? "未选择" : appPath)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(appPath.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button("选择…") { pickApp() }
                    }
                }
            }

            LabeledContent("名称") {
                TextField("显示名称", text: $name).textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("适用扩展名").font(.caption).foregroundStyle(.secondary)
                TextField("留空表示适用所有文件；逗号或空格分隔，如 txt, md", text: $extText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(foldersOnly)
                Text(foldersOnly ? "已设为仅在文件夹显示，扩展名不生效。" : "对文件夹右键时，所有应用都会显示。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Toggle("仅在文件夹右键时显示", isOn: $foldersOnly)
                .help("勾选后该应用只在右键文件夹时出现，右键文件时不出现")

            Toggle("折叠到「打开方式」菜单内", isOn: $collapsed)
                .help("关闭后该应用会直接显示在 Finder 右键菜单的一级菜单中")

            HStack {
                Spacer()
                Button("取消") { onCommit(nil) }.keyboardShortcut(.cancelAction)
                Button("保存", action: commit)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(appPath.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var modeTitle: String {
        switch mode {
        case .add: return "添加应用程序"
        case .edit: return "编辑应用程序"
        }
    }

    private var previewIcon: some View {
        Group {
            if !appPath.isEmpty {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                    .resizable().scaledToFit()
            } else {
                Image(systemName: "app.dashed")
                    .resizable().scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 48, height: 48)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.title = "选择应用程序"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            appPath = url.path
            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                name = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func commit() {
        let exts = AppEntry.normalizeExtensions(from: extText)
        let id: String
        switch mode {
        case .add: id = UUID().uuidString
        case .edit(let e): id = e.id
        }
        onCommit(AppEntry(
            id: id,
            name: name.trimmingCharacters(in: .whitespaces),
            appPath: appPath,
            allowedExtensions: exts,
            foldersOnly: foldersOnly,
            collapsed: collapsed
        ))
    }
}
