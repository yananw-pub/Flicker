//
//  ContentView.swift
//  Flicker
//
//  主窗口容器：侧边栏导航 + 内容面板。
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppEntryStore
    @State private var selectedItem: NavigationItem = .openWith

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedItem: $selectedItem)

            Divider()

            Group {
                switch selectedItem {
                case .openWith:
                    OpenWithPanel()
                case .actionControl:
                    ActionControlPanel()
                case .general:
                    GeneralSettingsPanel()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppEntryStore())
}
