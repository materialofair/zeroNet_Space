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

                ScrollView {
                    VStack(spacing: 30) {
                        // 头部图标
                        headerSection

                        // 密码输入区域
                        passwordSection

                        // 登录按钮
                        loginButton

                        // 忘记密码提示
                        forgotPasswordHint

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // 立即聚焦密码输入框，无需延迟
                isPasswordFocused = true
            }
        }
        .loadingOverlay(
            isShowing: viewModel.isProcessing,
            message: String(localized: "login.verifying")
        )
    }

    // MARK: - View Components

    /// 头部区域
    private var headerSection: some View {
        VStack(spacing: 20) {
            // 应用图标
            Image("LoginHero")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(.top, 60)

            VStack(spacing: 8) {
                Text(String(localized: "login.title"))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(ColorTheme.primaryText)

                Text(String(localized: "login.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// 密码输入区域
    private var passwordSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
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
                    .font(.caption)
                    .foregroundStyle(ColorTheme.destructive)
                    .padding(.horizontal, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
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
            HStack(spacing: 12) {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                    Text(String(localized: "login.unlock"))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
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
            .cornerRadius(16)
            .shadow(
                color: viewModel.isLoginButtonEnabled ? .blue.opacity(0.3) : .clear,
                radius: 10,
                x: 0,
                y: 5
            )
        }
        .disabled(!viewModel.isLoginButtonEnabled || viewModel.isProcessing)
        .padding(.horizontal)
        .padding(.top, 10)
    }

    /// 忘记密码提示
    private var forgotPasswordHint: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(ColorTheme.warning)
                    Text(String(localized: "login.forgotPassword"))
                        .fontWeight(.medium)
                        .foregroundStyle(ColorTheme.primaryText)
                }
                .font(.subheadline)

                Text(String(localized: "login.forgotPasswordWarning"))
                    .font(.caption)
                    .foregroundStyle(ColorTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(ColorTheme.warning.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.top, 20)
    }
}

// MARK: - Preview

#Preview {
    LoginView()
}
