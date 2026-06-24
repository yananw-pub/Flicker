//
//  SidebarView.swift
//  Flicker
//
//  侧边栏导航组件，用于在主窗口中切换不同配置面板。
//

import SwiftUI

/// 导航项枚举
enum NavigationItem: String, CaseIterable, Identifiable {
    case openWith = "打开方式"
    case actionControl = "操作控制"
    case general = "通用设置"
    
    var icon: String {
        switch self {
        case .openWith: return "app.badge"
        case .actionControl: return "slider.horizontal.3"
        case .general: return "gearshape"
        }
    }
    
    var id: String { rawValue }
}

/// 侧边栏导航视图
struct SidebarView: View {
    @Binding var selectedItem: NavigationItem
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(NavigationItem.allCases) { item in
                SidebarItem(
                    item: item,
                    isSelected: selectedItem == item
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedItem = item
                    }
                }
            }
            Spacer()
        }
        .frame(width: 180)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

/// 单个导航项
private struct SidebarItem: View {
    let item: NavigationItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(item.rawValue)
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

#Preview {
    SidebarView(selectedItem: .constant(.openWith))
        .frame(height: 300)
}
