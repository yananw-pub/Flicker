//
//  Logger.swift
//  Flicker
//
//  统一日志工具，通过编译配置控制输出级别。
//  Debug 构建输出详细日志，Release 构建静默。
//

import Foundation
import os

/// 统一日志工具
enum Log {
    private static let logger = Logger(subsystem: "com.wangyanan.flicker", category: "general")
    
    /// 调试日志（仅 Debug 构建输出）
    static func debug(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        logger.debug("[\(fileName):\(line)] \(function) - \(msg)")
        #endif
    }
    
    /// 信息日志（始终输出）
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.info("[\(fileName):\(line)] \(function) - \(message)")
    }
    
    /// 错误日志（始终输出）
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.error("[\(fileName):\(line)] \(function) - \(message)")
    }
}
