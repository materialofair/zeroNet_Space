//
//  ContentView.swift
//  ZeroNet-Space
//
//  主内容视图（已认证后显示）
//  使用 MainTabView 展示标签栏界面
//

import SwiftData
import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authViewModel: AuthenticationViewModel

    var body: some View {
        MainTabView()
            .environmentObject(authViewModel)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MediaItem.self, inMemory: true)
}
