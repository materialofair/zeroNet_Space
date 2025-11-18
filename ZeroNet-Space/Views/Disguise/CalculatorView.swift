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

    var body: some View {
        ZStack {
            // 黑色背景（系统计算器风格）
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer()

                // 显示屏
                displayView

                // 按钮网格
                ForEach(buttons, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { button in
                            CalculatorButtonView(
                                button: button,
                                viewModel: viewModel
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .unlockFromDisguise)) { _ in
            // 收到解锁通知
            authViewModel.isAuthenticated = true
        }
    }

    // MARK: - Display View

    private var displayView: some View {
        Text(viewModel.state.displayValue)
            .font(.system(size: 80, weight: .light, design: .default))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)
            .padding(.bottom, 20)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

// MARK: - Calculator Button View

struct CalculatorButtonView: View {
    let button: CalculatorButton
    @ObservedObject var viewModel: CalculatorViewModel

    var body: some View {
        Button(action: {
            handleButtonPress()
        }) {
            Text(button.title)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.white)
                .frame(
                    width: buttonWidth(),
                    height: buttonHeight()
                )
                .background(button.backgroundColor)
                .cornerRadius(buttonHeight() / 2)
        }
    }

    // MARK: - Button Dimensions

    private func buttonWidth() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let totalSpacing: CGFloat = 5 * 12  // 4 gaps + padding
        let buttonSize = (screenWidth - totalSpacing) / 4

        // 0 按钮占两列
        if button == .zero {
            return buttonSize * 2 + 12
        }
        return buttonSize
    }

    private func buttonHeight() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let totalSpacing: CGFloat = 5 * 12
        return (screenWidth - totalSpacing) / 4
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
