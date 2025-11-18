//
//  LaunchScreenView.swift
//  零网络空间 (ZeroNet Space)
//
//  启动页视图 - 完全离线的私密加密空间
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.7, green: 0.9, blue: 1.0),
                    Color(red: 0.9, green: 0.95, blue: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Logo
            VStack(spacing: 0) {
                // 螺旋图标
                SpiralLogo()
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
}

// 螺旋Logo绘制
struct SpiralLogo: View {
    var body: some View {
        ZStack {
            // 外圈螺旋
            SpiralShape(turns: 1.5, lineWidth: 3)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.8, blue: 0.9),
                            Color(red: 0.5, green: 0.85, blue: 0.95),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )

            // 内圈
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.82, blue: 0.92),
                            Color(red: 0.5, green: 0.87, blue: 0.96),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3
                )
                .frame(width: 50, height: 50)

            // 内圈点
            Circle()
                .fill(Color(red: 0.5, green: 0.85, blue: 0.95))
                .frame(width: 12, height: 12)
                .offset(x: -12, y: -8)

            Circle()
                .fill(Color(red: 0.5, green: 0.85, blue: 0.95))
                .frame(width: 12, height: 12)
                .offset(x: 12, y: 8)

            // 外圈端点
            Circle()
                .fill(Color(red: 0.4, green: 0.8, blue: 0.9))
                .frame(width: 10, height: 10)
                .offset(x: -45, y: -50)

            Circle()
                .fill(Color(red: 0.5, green: 0.85, blue: 0.95))
                .frame(width: 10, height: 10)
                .offset(x: 45, y: 50)
        }
        .frame(width: 120, height: 120)
    }
}

// 螺旋形状
struct SpiralShape: Shape {
    let turns: Double
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - lineWidth

        let steps = 200
        let angleStep = (turns * 2 * .pi) / Double(steps)

        for step in 0...steps {
            let angle = angleStep * Double(step)
            let radiusMultiplier = 1.0 - (Double(step) / Double(steps)) * 0.6
            let x = center.x + CGFloat(cos(angle)) * radius * CGFloat(radiusMultiplier)
            let y = center.y + CGFloat(sin(angle)) * radius * CGFloat(radiusMultiplier)

            if step == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

#Preview {
    LaunchScreenView()
}
