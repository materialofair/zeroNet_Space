//
//  EncryptedFilePasswordInputView.swift
//  ZeroNet-Space
//
//  加密文件密码输入视图
//  用于导入旧加密文件时输入原始密码
//

import SwiftUI

struct EncryptedFilePasswordInputView: View {
    @Environment(\.dismiss) private var dismiss

    let fileName: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 图标
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                // 说明文本
                VStack(spacing: 12) {
                    Text("import.encryptedFile.title")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("import.encryptedFile.message")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Text(fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }

                // 密码输入框
                HStack {
                    if showPassword {
                        TextField(String(localized: "import.encryptedFile.passwordPlaceholder"), text: $password)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .focused($isPasswordFocused)
                    } else {
                        SecureField(String(localized: "import.encryptedFile.passwordPlaceholder"), text: $password)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .focused($isPasswordFocused)
                    }

                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)

                // 提示文本
                Text("import.encryptedFile.hint")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 20)

                Spacer()

                // 按钮
                HStack(spacing: 16) {
                    Button(action: {
                        onCancel()
                        dismiss()
                    }) {
                        Text("action.cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        onConfirm(password)
                        dismiss()
                    }) {
                        Text("action.confirm")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(password.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(password.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("import.encryptedFile.navigationTitle")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isPasswordFocused = true
            }
        }
    }
}

#Preview {
    EncryptedFilePasswordInputView(
        fileName: "example.encrypted",
        onConfirm: { _ in },
        onCancel: { }
    )
}
