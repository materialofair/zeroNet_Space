//
//  LaunchScreenView.swift
//  零网络空间 (ZeroNet Space)
//
//  启动页视图 - 开源 · 零网络 · 隐私优先
//  Last Modified: 2025-01-18 - 完美适配所有iPhone屏幕尺寸
//

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 渐变背景 - 与启动图片完美融合的紫蓝渐变
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.85, green: 0.82, blue: 0.92),  // 淡紫色 #D9D1EB
                        Color(red: 0.70, green: 0.75, blue: 0.90),  // 蓝紫色 #B3BFE6
                        Color(red: 0.45, green: 0.60, blue: 0.85),  // 深蓝色 #7399D9
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // 启动图片 - 使用 .scaledToFit() 确保完整显示不裁剪
                Image("LaunchImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .clipped()
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LaunchScreenView()
}
