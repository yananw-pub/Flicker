//
//  AppEntry.swift
//  Flicker
//
//  Shared between the container app and the Finder Sync extension.
//

import Foundation

/// 一个可配置的应用程序条目。
struct AppEntry: Codable, Identifiable, Equatable, Hashable {
    /// 稳定唯一 id（UUID 字符串）
    var id: String
    /// 显示名称（默认取 .app 名）
    var name: String
    /// .app 包的绝对路径
    var appPath: String
    /// 适用文件扩展名（小写、无点）。空数组表示适用所有文件。
    var allowedExtensions: [String]
    /// 仅在文件夹右键时显示该应用。
    /// 为 false 时按扩展名匹配文件（空数组适用所有文件），且对文件夹始终显示。
    var foldersOnly: Bool
    /// 是否折叠到「打开方式」子菜单内。
    /// 为 false 时直接显示在 Finder 右键菜单的一级菜单中。
    var collapsed: Bool

    /// 规范化扩展名字符串（兼容各种中英文逗号、分号、空格分隔，去除通配符与点）
    static func normalizeExtensions(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，;；、 \t\r\n")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .map { item -> String in
                var s = item
                if s.hasPrefix("*") { s = String(s.dropFirst()) }
                return s.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
            .filter { !$0.isEmpty }
    }

    init(id: String = UUID().uuidString,
         name: String,
         appPath: String,
         allowedExtensions: [String] = [],
         foldersOnly: Bool = false,
         collapsed: Bool = true) {
        self.id = id
        self.name = name
        self.appPath = appPath
        self.allowedExtensions = allowedExtensions
            .flatMap { Self.normalizeExtensions(from: $0) }
        self.foldersOnly = foldersOnly
        self.collapsed = collapsed
    }

    // 兼容旧配置：缺少 foldersOnly/collapsed 字段时使用默认值。
    private enum CodingKeys: String, CodingKey {
        case id, name, appPath, allowedExtensions, foldersOnly, collapsed
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        appPath = try c.decode(String.self, forKey: .appPath)
        let rawExts = try c.decodeIfPresent([String].self, forKey: .allowedExtensions) ?? []
        allowedExtensions = rawExts.flatMap { Self.normalizeExtensions(from: $0) }
        foldersOnly = try c.decodeIfPresent(Bool.self, forKey: .foldersOnly) ?? false
        collapsed = try c.decodeIfPresent(Bool.self, forKey: .collapsed) ?? true
    }

    /// URL 形式
    var url: URL { URL(fileURLWithPath: appPath) }

    /// 判断是否适用于给定 URL：
    /// - 文件夹：始终显示（无论 foldersOnly）。
    /// - 文件：foldersOnly 为 true 时不显示；否则按扩展名匹配，空数组适用全部。
    func matches(url: URL) -> Bool {
        let isFolder: Bool = {
            if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), let isDir = values.isDirectory {
                return isDir
            }
            var isDirObjC: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirObjC) {
                return isDirObjC.boolValue
            }
            return url.hasDirectoryPath
        }()

        if isFolder { return true }
        if foldersOnly { return false }
        if allowedExtensions.isEmpty { return true }

        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !ext.isEmpty else { return false }
        return allowedExtensions.contains(ext)
    }
}
