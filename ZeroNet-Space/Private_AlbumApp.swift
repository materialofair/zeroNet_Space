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

    // App 级 scenePhase 是所有 scene 的聚合状态。当前未开启 iPad 多窗口
    // （无 UIApplicationSupportsMultipleScenes），单 scene 下与窗口状态等价；
    // 若日后启用多窗口，隐私遮罩/自动锁定需下沉到 scene 级别
    @Environment(\.scenePhase) private var scenePhase
    /// 最近一次进入后台的时间（用于自动锁定判定）
    @State private var lastBackgroundedAt: Date?

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

                        // 仅当伪装密码确实存在时才展示计算器，
                        // 否则用户会被锁死在没有解锁路径的计算器界面
                        if disguiseModeEnabled && KeychainService.shared.isDisguisePasswordSet() {
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

                // 隐私遮罩：离开前台时盖住已解密内容，
                // 防止系统为多任务切换器截取的快照泄露隐私
                if authViewModel.isAuthenticated && scenePhase != .active && !showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .task {
                // 显示启动页1.5秒
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.easeOut(duration: 0.5)) {
                    showLaunchScreen = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    lastBackgroundedAt = Date()
                case .active:
                    autoLockIfNeeded()
                default:
                    break
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Auto Lock

    /// 回到前台时按"离开后自动锁定"设置决定是否登出。
    /// 只在真正进过后台（.background）后计时；短暂的 .inactive
    /// （如下拉通知中心、来电）不触发锁定，但隐私遮罩仍会覆盖
    private func autoLockIfNeeded() {
        defer { lastBackgroundedAt = nil }

        guard authViewModel.isAuthenticated,
            let backgroundedAt = lastBackgroundedAt
        else { return }

        let timeout = AppSettings.shared.autoLockTimeout
        guard timeout != .never else { return }

        if Date().timeIntervalSince(backgroundedAt) >= Double(timeout.rawValue) {
            authViewModel.logout()
        }
    }
}
