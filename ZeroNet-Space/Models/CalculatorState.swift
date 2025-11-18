//
//  CalculatorState.swift
//  ZeroNet-Space
//
//  计算器状态模型
//  用于伪装模式的计算器功能
//

import Foundation
import SwiftUI

/// 计算器状态模型
struct CalculatorState {
    var displayValue: String = "0"
    var previousValue: Double = 0
    var currentOperation: Operation? = nil
    var shouldResetDisplay: Bool = false
    var inputHistory: [String] = []  // 仅用于密码检测，不显示给用户

    /// 计算运算符
    enum Operation: String {
        case add = "+"
        case subtract = "-"
        case multiply = "×"
        case divide = "÷"

        /// 执行计算
        func calculate(_ a: Double, _ b: Double) -> Double {
            switch self {
            case .add: return a + b
            case .subtract: return a - b
            case .multiply: return a * b
            case .divide: return b != 0 ? a / b : 0
            }
        }
    }
}

/// 计算器按钮定义
enum CalculatorButton: Hashable {
    case zero, one, two, three, four, five, six, seven, eight, nine
    case add, subtract, multiply, divide
    case equals, clear, negate, percent, decimal

    var title: String {
        switch self {
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "×"
        case .divide: return "÷"
        case .equals: return "="
        case .clear: return "AC"
        case .negate: return "+/-"
        case .percent: return "%"
        case .decimal: return "."
        }
    }

    var backgroundColor: Color {
        switch self {
        case .add, .subtract, .multiply, .divide, .equals:
            return Color.orange
        case .clear, .negate, .percent:
            return Color.gray
        case .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .decimal:
            return Color(white: 0.3)
        }
    }
}
