//
//  MainTabView.swift
//  ZeroNet-Space
//
//  主标签栏视图
//  包含：相片、视频、文件、设置四个标签
//

import SwiftUI

struct MainTabView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var selectedTab = 0

    // MARK: - Body

    var body: some View {
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

            // 视频标签
            VideosView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label(
                        String(localized: "tab.videos"),
                        systemImage: selectedTab == 1 ? "play.rectangle.fill" : "play.rectangle")
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
                        systemImage: selectedTab == 3 ? "note.text" : "note.text")
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
        .tint(.blue)  // TabBar 选中颜色
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AuthenticationViewModel())
}
