//
//  AuthenticationMode.swift
//  ZeroNet_Space
//
//  Created by Claude on 2025-01-17.
//

import Foundation

/// 用户认证模式
enum AuthenticationMode {
    /// 主人模式 - 完整访问权限
    case owner

    /// 访客模式 - 受限访问权限（隐藏所有内容）
    case guest

    /// 未认证状态 - 默认状态，需要登录
    case unauthenticated
}
