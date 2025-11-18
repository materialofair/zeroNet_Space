//
//  LoadingOverlay.swift
//  ZeroNet-Space
//
//  全局加载等待层
//  提供统一的加载提示UI
//

import SwiftUI

/// 加载等待层视图
struct LoadingOverlay: View {
    let message: String
    let progress: Double?  // 0.0 到 1.0，nil 表示不确定进度

    init(message: String = String(localized: "common.loading"), progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // 加载卡片
            VStack(spacing: 20) {
                // 进度指示器
                if let progress = progress {
                    // 确定进度
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 60, height: 60)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.3), value: progress)

                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                } else {
                    // 不确定进度 - 旋转动画
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }

                // 提示文字
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
            .padding(40)
        }
    }
}

// MARK: - View Extension

extension View {
    /// 显示加载等待层
    /// - Parameters:
    ///   - isShowing: 是否显示
    ///   - message: 提示文字
    ///   - progress: 进度（0.0-1.0，nil表示不确定）
    func loadingOverlay(
        isShowing: Bool,
        message: String = String(localized: "common.loading"),
        progress: Double? = nil
    ) -> some View {
        ZStack {
            self

            if isShowing {
                LoadingOverlay(message: message, progress: progress)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isShowing)
    }
}

// MARK: - Preview

#Preview("Indeterminate Progress") {
    VStack {
        Text("Content Area")
    }
    .loadingOverlay(isShowing: true, message: String(localized: "common.processing"))
}

#Preview("Determinate Progress") {
    VStack {
        Text("Content Area")
    }
    .loadingOverlay(
        isShowing: true, message: String(localized: "common.importing.photos"), progress: 0.65)
}
