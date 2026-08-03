//
//  LaunchScreenView.swift
//  零网络空间 (ZeroNet Space)
//
//  启动页视图 - 开源 · 零网络 · 隐私优先
//  Last Modified: 2025-01-18 - 完美适配所有iPhone屏幕尺寸
//

import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
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

    private var backgroundGradient: LinearGradient {
        let colors: [Color] = colorScheme == .dark
            ? [
                Color(red: 0.03, green: 0.08, blue: 0.20),
                Color(red: 0.02, green: 0.05, blue: 0.14),
            ]
            : [
                Color(red: 0.98, green: 0.97, blue: 0.95),
                Color(red: 0.95, green: 0.96, blue: 0.99),
            ]

        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

#Preview {
    LaunchScreenView()
}
