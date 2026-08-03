//
//  CalculatorView.swift
//  ZeroNet-Space
//
//  伪装计算器界面
//  完全模仿系统计算器，支持密码序列解锁
//

import SwiftUI

struct CalculatorView: View {
    @StateObject private var viewModel = CalculatorViewModel()
    @EnvironmentObject private var authViewModel: AuthenticationViewModel

    // 计算器按钮布局（模仿iOS系统计算器）
    let buttons: [[CalculatorButton]] = [
        [.clear, .negate, .percent, .divide],
        [.seven, .eight, .nine, .multiply],
        [.four, .five, .six, .subtract],
        [.one, .two, .three, .add],
        [.zero, .decimal, .equals],
    ]

    // 按钮间距与左右留白
    private let buttonSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        ZStack {
            // 黑色背景（系统计算器风格）
            Color.black.ignoresSafeArea()

            // 用 GeometryReader 按可用区域计算按钮尺寸，
            // 适配不同机型与横屏/分屏，避免按屏幕宽度硬编码导致溢出
            GeometryReader { geometry in
                let availableWidth = max(geometry.size.width - horizontalPadding * 2, 0)
                let widthBasedButton = (availableWidth - buttonSpacing * 3) / 4

                // 显示屏预留约 22% 高度，其余给 5 行按钮
                let displayHeight = geometry.size.height * 0.22
                let buttonAreaHeight = max(
                    geometry.size.height - displayHeight - buttonSpacing * 2, 0)
                let heightBasedButton = (buttonAreaHeight - buttonSpacing * 4) / 5

                // 取宽高两个维度中更紧的那个，并保证最小可点击尺寸
                let buttonSize = max(min(widthBasedButton, heightBasedButton), 44)

                VStack(spacing: buttonSpacing) {
                    Spacer(minLength: 0)

                    // 显示屏
                    displayView(fontSize: min(80, buttonSize))

                    // 按钮网格
                    ForEach(buttons, id: \.self) { row in
                        HStack(spacing: buttonSpacing) {
                            ForEach(row, id: \.self) { button in
                                CalculatorButtonView(
                                    button: button,
                                    viewModel: viewModel,
                                    buttonSize: buttonSize,
                                    spacing: buttonSpacing
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, buttonSpacing)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .unlockFromDisguise)) { _ in
            // 收到解锁通知
            authViewModel.isAuthenticated = true
        }
    }

    // MARK: - Display View

    private func displayView(fontSize: CGFloat) -> some View {
        Text(viewModel.state.displayValue)
            .font(.system(size: fontSize, weight: .light, design: .default))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

// MARK: - Calculator Button View

struct CalculatorButtonView: View {
    let button: CalculatorButton
    @ObservedObject var viewModel: CalculatorViewModel
    let buttonSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        Button(action: {
            handleButtonPress()
        }) {
            Text(button.title)
                .font(.system(size: min(32, buttonSize * 0.4), weight: .medium))
                .foregroundColor(.white)
                .frame(
                    width: buttonWidth(),
                    height: buttonSize
                )
                .background(button.backgroundColor)
                .cornerRadius(buttonSize / 2)
        }
    }

    // MARK: - Button Dimensions

    private func buttonWidth() -> CGFloat {
        // 0 按钮占两列
        if button == .zero {
            return buttonSize * 2 + spacing
        }
        return buttonSize
    }

    // MARK: - Button Handler

    private func handleButtonPress() {
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        switch button {
        case .zero: viewModel.numberPressed(0)
        case .one: viewModel.numberPressed(1)
        case .two: viewModel.numberPressed(2)
        case .three: viewModel.numberPressed(3)
        case .four: viewModel.numberPressed(4)
        case .five: viewModel.numberPressed(5)
        case .six: viewModel.numberPressed(6)
        case .seven: viewModel.numberPressed(7)
        case .eight: viewModel.numberPressed(8)
        case .nine: viewModel.numberPressed(9)
        case .decimal: viewModel.decimalPressed()
        case .add: viewModel.operationPressed(.add)
        case .subtract: viewModel.operationPressed(.subtract)
        case .multiply: viewModel.operationPressed(.multiply)
        case .divide: viewModel.operationPressed(.divide)
        case .equals: viewModel.equalsPressed()
        case .clear: viewModel.clearPressed()
        case .negate: viewModel.negatePressed()
        case .percent: viewModel.percentPressed()
        }
    }
}

// MARK: - Preview

#Preview {
    CalculatorView()
        .environmentObject(AuthenticationViewModel())
}
