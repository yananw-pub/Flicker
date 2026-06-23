//
//  UpdateChecker.swift
//  Flicker
//
//  通过 GitHub Releases API 检查是否有新版本。
//  零第三方依赖，仅用 URLSession + JSONDecoder。
//

import AppKit

struct UpdateChecker {

    /// GitHub 仓库（owner/repo），发 Release 时 tag 格式为 v1.2.3。
    private static let owner = "yananw-pub"
    private static let repo  = "Flicker"

    /// 检查结果：无更新 / 有更新 / 检查失败。
    enum Result {
        case upToDate
        case updateAvailable(version: String, url: URL)
        case checkFailed(String)
    }

    // MARK: - Public

    /// 静默检查，有更新时弹窗提示用户。
    static func checkAndNotify() {
        Task {
            let result = await check()
            switch result {
            case .upToDate, .checkFailed:
                break // 静默；失败时无感知，不打扰用户
            case .updateAvailable(let version, let url):
                await MainActor.run {
                    showAlert(version: version, url: url)
                }
            }
        }
    }

    /// 手动检查（菜单项触发），无论是否有更新都给反馈。
    static func checkManually() {
        Task {
            let result = await check()
            await MainActor.run {
                switch result {
                case .upToDate:
                    showUpToDateAlert()
                case .updateAvailable(let version, let url):
                    showAlert(version: version, url: url)
                case .checkFailed(let message):
                    showFailureAlert(message: message)
                }
            }
        }
    }

    // MARK: - Core

    private static func check() async -> Result {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            return .checkFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                return .checkFailed("HTTP \(code)")
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let localVersion = Bundle.main.appVersion ?? "0.0.0"

            if compareVersions(remoteVersion, isNewerThan: localVersion),
               let htmlURL = URL(string: release.html_url) {
                return .updateAvailable(version: remoteVersion, url: htmlURL)
            } else {
                return .upToDate
            }
        } catch {
            return .checkFailed(error.localizedDescription)
        }
    }

    // MARK: - Version Comparison

    /// 语义版本比较：a.b.c > x.y.z → true
    static func compareVersions(_ lhs: String, isNewerThan rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".").compactMap { Int($0) }
        let rhsParts = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(lhsParts.count, rhsParts.count)
        for i in 0..<count {
            let l = i < lhsParts.count ? lhsParts[i] : 0
            let r = i < rhsParts.count ? rhsParts[i] : 0
            if l > r { return true }
            if l < r { return false }
        }
        return false
    }

    // MARK: - UI

    private static func showAlert(version: String, url: URL) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 v\(version)"
        alert.informativeText = "Flicker 有新版本可用，是否前往 GitHub 下载？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "稍后再说")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        }
    }

    private static func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "当前版本 v\(Bundle.main.appVersion ?? "?")"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    private static func showFailureAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
}

// MARK: - Models

private struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: String
}

// MARK: - Bundle Extension

private extension Bundle {
    var appVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
