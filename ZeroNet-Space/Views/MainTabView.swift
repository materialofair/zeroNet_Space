//
//  MainTabView.swift
//  ZeroNet-Space
//
//  主标签栏视图
//  包含：相片、影音、文件、记事本、设置五个标签
//

import SwiftUI

struct MainTabView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var selectedTab = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let expanded = AdaptiveVaultLayout.showsSidebar(width: geometry.size.width,
                                                           accessibility: typeSize.isAccessibilitySize)
            HStack(spacing: 0) {
                sidebar
                    .frame(width: expanded ? 200 : 0)
                    .clipped()
                    .opacity(expanded ? 1 : 0)
                    .allowsHitTesting(expanded)
                    .accessibilityHidden(!expanded)
                tabs
                    .environment(\.vaultUsesSidebar, expanded)
            }
        }
        .tint(.blue)
    }

    // Keep this TabView at the same structural location when width changes. Moving
    // whole screens between split/compact branches would discard navigation/drafts.
    private var tabs: some View {
        TabView(selection: $selectedTab) {
            // 相片标签
            PhotosView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label(
                        String(localized: "tab.photos"),
                        systemImage: selectedTab == 0 ? "photo.fill" : "photo")
                }
                .tag(0)

            // 影音标签（合并视频与音频）
            MediaView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label(
                        String(localized: "tab.media"),
                        systemImage: selectedTab == 1 ? "play.rectangle.on.rectangle.fill" : "play.rectangle.on.rectangle")
                }
                .tag(1)

            // 文件标签
            FilesView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label(
                        String(localized: "tab.files"),
                        systemImage: selectedTab == 2 ? "folder.fill" : "folder")
                }
                .tag(2)

            // 隐藏空间标签（现在作为普通记事本）
            SecretSpaceView()
                .tabItem {
                    Label(
                        String(localized: "tab.secretSpace"),
                        systemImage: selectedTab == 3 ? "note.text" : "note")
                }
                .tag(3)

            // 设置标签
            SettingsView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label(
                        String(localized: "tab.settings"),
                        systemImage: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                }
                .tag(4)
        }

    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("SealedPocket")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 20)
                sidebarButton(0, "tab.photos", "photo")
                sidebarButton(1, "tab.media", "play.rectangle.on.rectangle")
                sidebarButton(2, "tab.files", "folder")
                sidebarButton(3, "tab.secretSpace", "note.text")
                sidebarButton(4, "tab.settings", "gearshape")
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(alignment: .trailing) { Divider() }
        .accessibilityIdentifier("vault.sidebar")
    }

    private func sidebarButton(_ tab: Int, _ key: String.LocalizationValue, _ icon: String) -> some View {
        Button { selectedTab = tab } label: {
            Label(String(localized: key), systemImage: icon)
                .font(.body.weight(selectedTab == tab ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(selectedTab == tab ? Color.accentColor.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedTab == tab ? Color.accentColor : .primary)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
        .accessibilityIdentifier("vault.category.\(tab)")
    }

}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AuthenticationViewModel())
}
