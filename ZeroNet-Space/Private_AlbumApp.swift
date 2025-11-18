//
//  ZeroNetSpaceApp.swift
//  零网络空间 (ZeroNet Space)
//
//  Created by WangQiao on 2025/11/5.
//  Modified: 添加认证流程和MediaItem数据模型
//

import SwiftData
import SwiftUI

@main
struct Private_AlbumApp: App {

    // MARK: - State

    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var guestModeManager = GuestModeManager.shared
    @State private var showLaunchScreen = true

    // MARK: - SwiftData Container

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MediaItem.self,  // 媒体项模型
            SecretNote.self,  // 私密笔记模型
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 根据认证状态显示不同界面
                Group {
                    if authViewModel.isAuthenticated
                        && guestModeManager.currentMode != .unauthenticated
                    {
                        // 已认证且模式不为未认证状态 - 显示主应用
                        ContentView()
                            .environmentObject(authViewModel)
                            .environmentObject(guestModeManager)
                    } else {
                        // 未认证 - 显示认证界面
                        let disguiseModeEnabled = UserDefaults.standard.bool(
                            forKey: AppConstants.UserDefaultsKeys.disguiseModeEnabled)

                        if disguiseModeEnabled {
                            // 伪装模式启用 - 显示计算器界面
                            CalculatorView()
                                .environmentObject(authViewModel)
                                .environmentObject(guestModeManager)
                        } else if authViewModel.isPasswordSet {
                            // 已设置密码 - 显示登录界面
                            LoginView()
                                .environmentObject(authViewModel)
                                .environmentObject(guestModeManager)
                        } else {
                            // 未设置密码 - 显示设置密码界面
                            SetupPasswordView()
                                .environmentObject(authViewModel)
                                .environmentObject(guestModeManager)
                        }
                    }
                }
                .onAppear {
                    // 应用启动时检查密码状态
                    authViewModel.checkPasswordStatus()
                    print("🚀 零网络空间启动 - 离线加密私密空间")
                    print("📱 认证状态: \(authViewModel.isAuthenticated ? "已认证" : "未认证")")
                    print("🔐 密码状态: \(authViewModel.isPasswordSet ? "已设置" : "未设置")")
                }

                // 启动页
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // 显示启动页1.5秒
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.easeOut(duration: 0.5)) {
                    showLaunchScreen = false
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
