//
//  SetupPasswordView.swift
//  ZeroNet-Space
//
//  首次设置密码界面
//  引导用户创建应用密码
//

import SwiftUI

struct SetupPasswordView: View {

    // MARK: - Properties

    @EnvironmentObject private var viewModel: AuthenticationViewModel
    @FocusState private var focusedField: Field?

    // MARK: - Focus Field Enum

    private enum Field: Hashable {
        case password
        case confirmPassword
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        // 头部图标和标题
                        headerSection

                        // 密码输入表单
                        passwordForm

                        // 设置按钮
                        setupButton

                        // 密码提示
                        passwordHints

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - View Components

    /// 头部区域
    private var headerSection: some View {
        VStack(spacing: 20) {
            // 锁图标
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 40)

            VStack(spacing: 8) {
                Text("设置密码")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("创建一个密码来保护您的零网络空间")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// 密码输入表单
    private var passwordForm: some View {
        VStack(spacing: 20) {
            // 密码输入
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.showPassword {
                    TextField("输入密码", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                } else {
                    SecureField("输入密码", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                }

                // Password strength indicator
                if !viewModel.password.isEmpty {
                    HStack {
                        Text(String(localized: "setup.passwordStrength"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(viewModel.passwordStrength.text)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.passwordStrength.color)

                        Spacer()
                    }
                }
            }

            // 确认密码输入
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.showPassword {
                    TextField("再次输入密码", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.done)
                        .onSubmit {
                            if viewModel.isSetupButtonEnabled {
                                viewModel.setupPassword()
                            }
                        }
                } else {
                    SecureField("再次输入密码", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.done)
                        .onSubmit {
                            if viewModel.isSetupButtonEnabled {
                                viewModel.setupPassword()
                            }
                        }
                }

                // Password match indicator
                if !viewModel.confirmPassword.isEmpty {
                    HStack {
                        Image(
                            systemName: viewModel.password == viewModel.confirmPassword
                                ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundColor(
                            viewModel.password == viewModel.confirmPassword ? .green : .red)

                        Text(
                            viewModel.password == viewModel.confirmPassword
                                ? String(localized: "setup.passwordMatch")
                                : String(localized: "setup.passwordMismatch")
                        )
                        .font(.caption)
                        .foregroundColor(
                            viewModel.password == viewModel.confirmPassword ? .green : .red)

                        Spacer()
                    }
                }
            }

            // Show/hide password toggle
            Button(action: {
                viewModel.togglePasswordVisibility()
            }) {
                HStack {
                    Image(systemName: viewModel.showPassword ? "eye.slash.fill" : "eye.fill")
                    Text(
                        viewModel.showPassword
                            ? String(localized: "setup.hidePassword")
                            : String(localized: "setup.showPassword"))
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // 错误消息
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 5)
    }

    /// 设置按钮
    private var setupButton: some View {
        Button(action: {
            viewModel.setupPassword()
        }) {
            HStack {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("完成设置")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(viewModel.isSetupButtonEnabled ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.isSetupButtonEnabled)
    }

    /// Password hints
    private var passwordHints: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "setup.requirement.length"), systemImage: "checkmark.circle")
            Label(String(localized: "setup.requirement.combination"), systemImage: "key")
            Label(
                String(localized: "setup.requirement.important"),
                systemImage: "exclamationmark.triangle")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    SetupPasswordView()
}
