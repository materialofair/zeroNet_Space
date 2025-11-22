//
//  DisguiseSettingsView.swift
//  ZeroNet-Space
//
//  计算器登录模式设置界面
//  开启/关闭计算器登录模式，设置密码序列
//

import SwiftData
import SwiftUI

struct DisguiseSettingsView: View {
    @AppStorage(AppConstants.UserDefaultsKeys.disguiseModeEnabled)
    private var disguiseModeEnabled: Bool = false

    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @StateObject private var reencryptionService = FileReencryptionService.shared

    private let keychainService = KeychainService.shared

    @State private var showPasswordChangeRequired = false
    @State private var hasDisguisePassword: Bool = false

    var body: some View {
        Form {
            // 计算器登录模式开关
            Section {
                Toggle(
                    String(localized: "calculatorLogin.enable.title"), isOn: $disguiseModeEnabled
                )
                .onChange(of: disguiseModeEnabled) { oldValue, newValue in
                    if newValue {
                        checkAndSetupDisguiseMode()
                    }
                }
            } header: {
                Text(String(localized: "calculatorLogin.title"))
            } footer: {
                Text(String(localized: "calculatorLogin.enable.description"))
            }

            if disguiseModeEnabled {
                // 密码序列状态（只读显示）
                Section {
                    HStack {
                        Text(String(localized: "calculatorLogin.passwordSequence"))
                        Spacer()
                        if hasDisguisePassword {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(
                                    String(localized: "calculatorLogin.passwordSequence.autoSynced")
                                )
                                .foregroundColor(.green)
                                .font(.caption)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(String(localized: "calculatorLogin.passwordSequence.notSet"))
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "calculatorLogin.unlockPassword"))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "calculatorLogin.passwordSequence.autoSyncHint"))
                            .foregroundColor(.secondary)

                        Text(String(localized: "calculatorLogin.instructions.howTo"))
                        Text(String(localized: "calculatorLogin.instructions.example"))
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }

                // 使用说明
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionRow(
                            icon: "checkmark.circle.fill",
                            text: String(localized: "calculatorLogin.tip.calculator"),
                            color: .green
                        )

                        InstructionRow(
                            icon: "eye.slash.fill",
                            text: String(localized: "calculatorLogin.tip.numbersOnly"),
                            color: .blue
                        )

                        InstructionRow(
                            icon: "lock.fill",
                            text: String(localized: "calculatorLogin.tip.noDisplay"),
                            color: .purple
                        )

                        InstructionRow(
                            icon: "exclamationmark.triangle.fill",
                            text: String(localized: "calculatorLogin.tip.noFeedback"),
                            color: .orange
                        )
                    }
                } header: {
                    Text(String(localized: "calculatorLogin.instructions.title"))
                }

                // 安全提示
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "calculatorLogin.security.title"))
                                    .fontWeight(.semibold)

                                Text(String(localized: "calculatorLogin.security.tips"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "calculatorLogin.settings.title"))
        .onAppear {
            // 迁移旧密码
            keychainService.migrateDisguisePasswordFromUserDefaults()
            // 检查密码状态
            hasDisguisePassword = keychainService.isDisguisePasswordSet()
        }
        .alert(
            String(localized: "calculatorLogin.changePassword.required.title"),
            isPresented: $showPasswordChangeRequired
        ) {
            Button(String(localized: "common.ok")) {
                // User needs to change their main password to enable calculator login mode
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                disguiseModeEnabled = false
            }
        } message: {
            Text(String(localized: "calculatorLogin.changePassword.required.message"))
        }
    }

    // MARK: - Methods

    private func checkAndSetupDisguiseMode() {
        guard let sessionPassword = authViewModel.sessionLoginPassword else {
            // 没有会话密码，要求重新登录
            disguiseModeEnabled = false
            return
        }

        // 检查主密码是否符合计算器登录模式要求（仅数字和小数点）
        if isValidDisguisePassword(sessionPassword) {
            // 主密码符合要求，保存到 Keychain
            do {
                try keychainService.saveDisguisePassword(sessionPassword)
                hasDisguisePassword = true
                print("✅ 主密码符合计算器登录模式要求，已自动设置")
            } catch {
                print("❌ 保存计算器登录密码失败: \(error)")
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

// MARK: - Preview

#Preview {
    NavigationStack {
        DisguiseSettingsView()
    }
}
