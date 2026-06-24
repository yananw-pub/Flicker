//
//  MenuSettings.swift
//  Flicker
//
//  Shared between the container app and the Finder Sync extension.
//  Controls which copy-related menu items appear in the Finder context menu.
//

import Foundation

/// 右键菜单显示设置，控制复制类菜单项的显隐。
struct MenuSettings: Codable {
    /// 显示「复制绝对路径」
    var showCopyAbsolutePath: Bool
    /// 显示「复制相对路径」
    var showCopyRelativePath: Bool
    /// 显示「复制文件名」
    var showCopyFileName: Bool

    /// 默认全开。
    static let defaults = MenuSettings(
        showCopyAbsolutePath: true,
        showCopyRelativePath: true,
        showCopyFileName: true
    )

    // 兼容旧配置：缺少字段时用默认值。
    init(
        showCopyAbsolutePath: Bool = true,
        showCopyRelativePath: Bool = true,
        showCopyFileName: Bool = true
    ) {
        self.showCopyAbsolutePath = showCopyAbsolutePath
        self.showCopyRelativePath = showCopyRelativePath
        self.showCopyFileName = showCopyFileName
    }

    private enum CodingKeys: String, CodingKey {
        case showCopyAbsolutePath, showCopyRelativePath, showCopyFileName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showCopyAbsolutePath = try c.decodeIfPresent(Bool.self, forKey: .showCopyAbsolutePath) ?? true
        showCopyRelativePath = try c.decodeIfPresent(Bool.self, forKey: .showCopyRelativePath) ?? true
        showCopyFileName = try c.decodeIfPresent(Bool.self, forKey: .showCopyFileName) ?? true
    }
}

// MARK: - 新建文件类型

/// 新建文件类型配置
struct NewFileType: Codable, Identifiable, Hashable {
    /// 唯一标识
    let id: String
    /// 显示名称
    let name: String
    /// 文件扩展名（不含点）
    let ext: String
    /// SF Symbols 图标名称
    let icon: String
    
    /// 默认支持的文件类型
    static let defaults: [NewFileType] = [
        NewFileType(id: "txt", name: "文本文档", ext: "txt", icon: "doc.text"),
        NewFileType(id: "conf", name: "配置文件", ext: "conf", icon: "gearshape"),
        NewFileType(id: "md", name: "Markdown", ext: "md", icon: "doc.richtext"),
        NewFileType(id: "toml", name: "TOML", ext: "toml", icon: "doc.plaintext"),
        NewFileType(id: "yaml", name: "YAML", ext: "yaml", icon: "doc.plaintext"),
        NewFileType(id: "yml", name: "YML", ext: "yml", icon: "doc.plaintext")
    ]
}

// MARK: - 新建文件设置

/// 新建文件功能设置
struct NewFileSettings: Codable {
    /// 启用的文件类型ID列表
    var enabledTypes: [String]
    /// 创建后自动打开
    var autoOpen: Bool
    
    /// 默认设置：启用txt和md，自动打开
    static let defaults = NewFileSettings(
        enabledTypes: ["txt", "md"],
        autoOpen: true
    )
    
    // 兼容旧配置：缺少字段时用默认值。
    init(
        enabledTypes: [String] = ["txt", "md"],
        autoOpen: Bool = true
    ) {
        self.enabledTypes = enabledTypes
        self.autoOpen = autoOpen
    }
    
    private enum CodingKeys: String, CodingKey {
        case enabledTypes, autoOpen
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabledTypes = try c.decodeIfPresent([String].self, forKey: .enabledTypes) ?? ["txt", "md"]
        autoOpen = try c.decodeIfPresent(Bool.self, forKey: .autoOpen) ?? true
    }
}
