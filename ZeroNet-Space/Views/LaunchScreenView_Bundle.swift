//
//  LaunchScreenView_Bundle.swift
//  零网络空间 (ZeroNet Space)
//
//  启动页视图 - 使用Bundle资源（备用方案）
//

import SwiftUI

struct LaunchScreenView_Bundle: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // 方式1: 从Bundle加载图片
            if let uiImage = UIImage(named: "launch_screen") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(isAnimating ? 1.0 : 0.0)
            } else {
                // 如果图片加载失败，显示后备视图
                FallbackLaunchView()
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
}

// 后备启动视图（如果图片加载失败）
struct FallbackLaunchView: View {
    var body: some View {
        ZStack {
            // 渐变背景（匹配你的图片色调）
            LinearGradient(
                colors: [
                    Color(red: 0.66, green: 0.71, blue: 0.90),  // 浅薰衣草紫
                    Color(red: 0.48, green: 0.56, blue: 0.82),  // 长春花蓝
                    Color(red: 0.18, green: 0.24, blue: 0.44),  // 深海军蓝
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // 断链图标（简化版）
                ZStack {
                    // 左半链条
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 60, height: 24)
                        .offset(x: -20, y: 0)

                    // 右半链条
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.0, green: 0.9, blue: 1.0))
                        .frame(width: 60, height: 24)
                        .offset(x: 20, y: 0)
                }
                .frame(height: 100)

                // 文本
                VStack(spacing: 12) {
                    Text("Open Source · Zero Network")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Text("Privacy First")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()
            }
        }
    }
}

#Preview {
    LaunchScreenView_Bundle()
}
