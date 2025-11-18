//
//  DisguiseSettingsView.swift
//  ZeroNet-Space
//
//  伪装模式设置界面
//  开启/关闭伪装模式，设置密码序列
//

import SwiftData
import SwiftUI

struct DisguiseSettingsView: View {
    @AppStorage(AppConstants.UserDefaultsKeys.disguiseModeEnabled)
    private var disguiseModeEnabled: Bool = false

    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @StateObject private var reencryptionService = FileReencryptionService.shared

    private let keychainService = KeychainService.shared

    @State private var showPasswordInput = false
    @State private var showDisguiseWarning = false
    @State private var showPasswordChangeRequired = false
    @State private var hasDisguisePassword: Bool = false

    var body: some View {
        Form {
            // 伪装模式开关
            Section {
                Toggle(String(localized: "disguise.enable.title"), isOn: $disguiseModeEnabled)
                    .onChange(of: disguiseModeEnabled) { oldValue, newValue in
                        if newValue {
                            checkAndSetupDisguiseMode()
                        }
                    }
            } header: {
                Text(String(localized: "disguise.calculator.title"))
            } footer: {
                Text(String(localized: "disguise.enable.description"))
            }

            if disguiseModeEnabled {
                // 密码序列设置
                Section {
                    HStack {
                        Text(String(localized: "disguise.passwordSequence"))
                        Spacer()
                        if hasDisguisePassword {
                            Text(String(localized: "disguise.isSet"))
                                .foregroundColor(.green)
                        } else {
                            Text(String(localized: "disguise.useDefault"))
                                .foregroundColor(.orange)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showPasswordInput = true
                    }
                } header: {
                    Text(String(localized: "disguise.unlockPassword"))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "disguise.instructions.howTo"))
                        Text(String(localized: "disguise.instructions.example"))
                            .foregroundColor(.secondary)

                        if !hasDisguisePassword {
                            Text(String(localized: "disguise.warning.defaultPassword"))
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.caption)
                }

                // 使用说明
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionRow(
                            icon: "checkmark.circle.fill",
                            text: String(localized: "disguise.tip.calculator"),
                            color: .green
                        )

                        InstructionRow(
                            icon: "eye.slash.fill",
                            text: String(localized: "disguise.tip.numbersOnly"),
                            color: .blue
                        )

                        InstructionRow(
                            icon: "lock.fill",
                            text: String(localized: "disguise.tip.noDisplay"),
                            color: .purple
                        )

                        InstructionRow(
                            icon: "exclamationmark.triangle.fill",
                            text: String(localized: "disguise.tip.noFeedback"),
                            color: .orange
                        )
                    }
                } header: {
                    Text(String(localized: "disguise.instructions.title"))
                }

                // 安全提示
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "disguise.security.title"))
                                    .fontWeight(.semibold)

                                Text(String(localized: "disguise.security.tips"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "disguise.title"))
        .onAppear {
            // 迁移旧密码
            keychainService.migrateDisguisePasswordFromUserDefaults()
            // 检查密码状态
            hasDisguisePassword = keychainService.isDisguisePasswordSet()
        }
        .sheet(isPresented: $showPasswordInput) {
            PasswordSequenceInputView(onSave: { newPassword in
                hasDisguisePassword = keychainService.isDisguisePasswordSet()
            })
        }
        .alert("启用伪装模式", isPresented: $showDisguiseWarning) {
            Button(String(localized: "common.continue")) {
                showPasswordInput = true
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                disguiseModeEnabled = false
            }
        } message: {
            Text("启用伪装模式后，应用将以计算器界面启动。请设置一个密码序列用于解锁应用。")
        }
        .alert(String(localized: "disguise.changePassword.required.title"), isPresented: $showPasswordChangeRequired) {
            Button(String(localized: "disguise.changePassword.action")) {
                showPasswordInput = true
            }
            Button("取消", role: .cancel) {
                disguiseModeEnabled = false
            }
        } message: {
            Text(String(localized: "disguise.changePassword.required.message"))
        }
    }

    // MARK: - Methods

    private func checkAndSetupDisguiseMode() {
        guard let sessionPassword = authViewModel.sessionLoginPassword else {
            // 没有会话密码，要求重新登录
            disguiseModeEnabled = false
            return
        }

        // 检查主密码是否符合伪装模式要求（仅数字和小数点）
        if isValidDisguisePassword(sessionPassword) {
            // 主密码符合要求，保存到 Keychain
            do {
                try keychainService.saveDisguisePassword(sessionPassword)
                hasDisguisePassword = true
                print("✅ 主密码符合伪装模式要求，已自动设置")
            } catch {
                print("❌ 保存伪装密码失败: \(error)")
                disguiseModeEnabled = false
            }
        } else {
            // 主密码不符合要求，提示用户修改
            showPasswordChangeRequired = true
            print("⚠️ 主密码包含非数字字符，需要修改")
        }
    }

    private func isValidDisguisePassword(_ password: String) -> Bool {
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        let passwordCharacters = CharacterSet(charactersIn: password)
        return passwordCharacters.isSubset(of: allowedCharacters)
    }
}

// MARK: - Instruction Row Component

struct InstructionRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Password Sequence Input View

struct PasswordSequenceInputView: View {
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authViewModel: AuthenticationViewModel

    private let keychainService = KeychainService.shared

    @State private var inputText: String = ""
    @State private var errorMessage: String?
    @State private var needsPasswordChange: Bool = false
    @State private var showReencryptionConfirm = false
    @State private var isReencrypting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "disguise.input.placeholder"), text: $inputText)
                        .keyboardType(.decimalPad)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                } header: {
                    Text(String(localized: "disguise.passwordSetup.title"))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if needsPasswordChange {
                            Text(String(localized: "disguise.passwordSetup.warning"))
                                .foregroundColor(.orange)
                                .fontWeight(.semibold)
                            Text(String(localized: "disguise.passwordSetup.instruction1"))
                                .foregroundColor(.orange)
                            Text(String(localized: "disguise.passwordSetup.instruction2"))
                                .foregroundColor(.red)
                        } else {
                            Text(String(localized: "disguise.passwordSetup.compatible"))
                                .foregroundColor(.green)
                            Text(String(localized: "disguise.passwordSetup.canUse"))
                        }

                        Text(String(localized: "disguise.passwordSetup.rule1"))
                        Text(String(localized: "disguise.passwordSetup.rule2"))

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                }

                // 示例
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        ExampleRow(password: "1234", description: String(localized: "disguise.example.simple"))
                        ExampleRow(password: "6789", description: String(localized: "disguise.example.sequential"))
                        ExampleRow(password: "3.14159", description: String(localized: "disguise.example.decimal"))
                        ExampleRow(password: "20241115", description: String(localized: "disguise.example.date"))
                    }
                } header: {
                    Text(String(localized: "disguise.example.title"))
                }
            }
            .navigationTitle(String(localized: "disguise.setPassword.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        savePassword()
                    }
                    .disabled(isReencrypting)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isReencrypting)
                }
            }
            .alert(String(localized: "disguise.confirmChange.title"), isPresented: $showReencryptionConfirm) {
                Button(String(localized: "disguise.confirmChange.continue"), role: .destructive) {
                    performPasswordChange()
                }
                Button("取消", role: .cancel) {
                    // 不做任何操作
                }
            } message: {
                Text(String(localized: "disguise.confirmChange.message"))
            }
            .overlay {
                if isReencrypting {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        ProgressView(String(localized: "disguise.updating"))
                            .tint(.white)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .onAppear {
            // 检查当前主密码是否符合伪装模式要求
            if let currentPassword = authViewModel.sessionLoginPassword ?? authViewModel.sessionPassword {
                let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
                let passwordCharacters = CharacterSet(charactersIn: currentPassword)
                needsPasswordChange = !passwordCharacters.isSubset(of: allowedCharacters)

                if !needsPasswordChange {
                    // 主密码符合要求，直接使用
                    inputText = currentPassword
                } else {
                    // 主密码不符合要求，清空输入
                    inputText = ""
                }
            } else {
                // 尝试从 Keychain 读取已保存的密码
                inputText = keychainService.loadDisguisePassword() ?? ""
            }
        }
    }

    private func savePassword() {
        errorMessage = nil

        // 验证输入（仅允许数字和小数点）
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        let inputCharacters = CharacterSet(charactersIn: inputText)

        if !inputCharacters.isSubset(of: allowedCharacters) {
            errorMessage = String(localized: "disguise.error.numbersOnly")
            return
        }

        // 至少4位
        if inputText.isEmpty || inputText.count < 4 {
            errorMessage = String(localized: "disguise.error.minLength")
            return
        }

        // 如果需要修改主密码，先确认是否需要重新加密文件
        if needsPasswordChange {
            showReencryptionConfirm = true
        } else {
            // 不需要修改主密码，保存到 Keychain
            do {
                try keychainService.saveDisguisePassword(inputText)
                onSave(inputText)
                dismiss()
                print("✅ 伪装模式密码已设置: \(inputText)")
            } catch {
                errorMessage = "保存失败: \(error.localizedDescription)"
                print("❌ 保存伪装密码失败: \(error)")
            }
        }
    }

    private func performPasswordChange() {
        guard let oldPassword = authViewModel.sessionLoginPassword else {
            errorMessage = String(localized: "disguise.error.noPassword")
            return
        }

        isReencrypting = true

        Task {
            do {
                try authViewModel.updatePassword(oldPassword: oldPassword, newPassword: inputText)

                // 保存新密码到 Keychain
                try keychainService.saveDisguisePassword(inputText)

                await MainActor.run {
                    onSave(inputText)
                    isReencrypting = false
                    dismiss()
                    print("✅ 密码修改成功")
                }

            } catch {
                await MainActor.run {
                    errorMessage = "密码修改失败: \(error.localizedDescription)"
                    isReencrypting = false
                    print("❌ 密码修改失败: \(error)")
                }
            }
        }
    }
}

// MARK: - Example Row Component

struct ExampleRow: View {
    let password: String
    let description: String

    var body: some View {
        HStack {
            Text(password)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)

            Spacer()

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DisguiseSettingsView()
    }
}
