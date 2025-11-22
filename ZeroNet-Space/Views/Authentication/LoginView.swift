//
//  LoginView.swift
//  ZeroNet-Space
//
//  登录界面
//  验证用户密码
//

import SwiftUI

struct LoginView: View {

    // MARK: - Properties

    @EnvironmentObject private var viewModel: AuthenticationViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isPasswordFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ColorTheme.primaryBackground
                    .ignoresSafeArea()

                // 装饰性渐变 (浅色模式)
                LinearGradient(
                    colors: [ColorTheme.accent.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .opacity(colorScheme == .light ? 1 : 0.3)

                VStack(spacing: 24) {
                    Spacer()

                    // 头部图标
                    headerSection

                    // 零网络隐私提醒
                    privacyNotice

                    // 密码输入区域
                    passwordSection

                    // 登录按钮
                    loginButton

                    // 隐私保护声明（紧凑版）
                    privacyStatement

                    Spacer()

                    // 忘记密码提示（底部）
                    forgotPasswordHint
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .loadingOverlay(
            isShowing: viewModel.isProcessing,
            message: String(localized: "login.verifying")
        )
    }

    // MARK: - View Components

    /// 头部区域
    private var headerSection: some View {
        VStack(spacing: 12) {
            // 应用图标（缩小）
            Image("LoginHero")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 15, y: 8)

            VStack(spacing: 4) {
                Text(String(localized: "login.title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(ColorTheme.primaryText)

                Text(String(localized: "login.subtitle"))
                    .font(.caption)
                    .foregroundStyle(ColorTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// 零网络隐私提醒
    private var privacyNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "login.privacy.zeronetwork"))
                    .font(.headline)
                    .foregroundStyle(ColorTheme.primaryText)

                Text(String(localized: "login.privacy.networkNotice"))
                    .font(.caption)
                    .foregroundStyle(ColorTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    /// 密码输入区域
    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 密码输入框
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                    .frame(width: 20)

                if viewModel.showPassword {
                    TextField(
                        String(localized: "login.passwordPlaceholder"),
                        text: $viewModel.password
                    )
                    .textContentType(.password)
                    .focused($isPasswordFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if viewModel.isLoginButtonEnabled {
                            viewModel.login()
                        }
                    }
                } else {
                    SecureField(
                        String(localized: "login.passwordPlaceholder"),
                        text: $viewModel.password
                    )
                    .textContentType(.password)
                    .focused($isPasswordFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if viewModel.isLoginButtonEnabled {
                            viewModel.login()
                        }
                    }
                }

                // 显示/隐藏密码按钮
                Button(action: {
                    viewModel.togglePasswordVisibility()
                }) {
                    Image(systemName: viewModel.showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(ColorTheme.secondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        viewModel.errorMessage != nil
                            ? ColorTheme.destructive : ColorTheme.border,
                        lineWidth: 1)
            )

            // 错误消息
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(ColorTheme.destructive)
                .padding(.horizontal, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut, value: viewModel.errorMessage)
        .disabled(viewModel.isProcessing)
    }

    /// 登录按钮
    private var loginButton: some View {
        Button(action: {
            isPasswordFocused = false  // 收起键盘
            viewModel.login()
        }) {
            HStack(spacing: 10) {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.body)
                    Text(String(localized: "login.unlock"))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                viewModel.isLoginButtonEnabled
                    ? LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        colors: [.gray, .gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .foregroundColor(.white)
            .cornerRadius(14)
            .shadow(
                color: viewModel.isLoginButtonEnabled ? .blue.opacity(0.3) : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(!viewModel.isLoginButtonEnabled || viewModel.isProcessing)
        .padding(.horizontal)
    }

    /// 忘记密码提示（紧凑版）
    private var forgotPasswordHint: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(ColorTheme.warning)
                Text(String(localized: "login.forgotPassword"))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(ColorTheme.secondaryText)
            }

            Text(String(localized: "login.forgotPasswordWarning"))
                .font(.caption2)
                .foregroundStyle(ColorTheme.secondaryText.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
    }

    /// 隐私保护声明（紧凑版）
    private var privacyStatement: some View {
        VStack(spacing: 10) {
            // 核心价值观 - 横向紧凑布局
            HStack(spacing: 12) {
                // 开源
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(String(localized: "login.privacy.opensource"))
                        .font(.caption2)
                        .fontWeight(.medium)
                }

                Text("•")
                    .foregroundStyle(ColorTheme.secondaryText.opacity(0.5))
                    .font(.caption2)

                // 零网络
                HStack(spacing: 4) {
                    Image(systemName: "network.slash")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text(String(localized: "login.privacy.zeronetwork"))
                        .font(.caption2)
                        .fontWeight(.medium)
                }

                Text("•")
                    .foregroundStyle(ColorTheme.secondaryText.opacity(0.5))
                    .font(.caption2)

                // 隐私优先
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(String(localized: "login.privacy.privacyfirst"))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(ColorTheme.primaryText)

            // 隐私承诺文字
            Text(String(localized: "login.privacy.description"))
                .font(.caption2)
                .foregroundStyle(ColorTheme.secondaryText.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    LoginView()
}
