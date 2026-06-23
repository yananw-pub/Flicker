//
//  AppActions.swift
//  Flicker
//
//  桥接 SwiftUI 场景动作与 AppKit（托盘菜单 / AppDelegate）。
//  在 SwiftUI 场景根捕获 openWindow / openSettings 闭包，
//  使得窗口关闭后 AppKit 侧仍可通过 AppActions 重新打开窗口。
//

import SwiftUI

@MainActor
final class AppActions {
    static let shared = AppActions()

    var openMainWindow: (() -> Void)?
    var openSettings: (() -> Void)?

    private init() {}
}
