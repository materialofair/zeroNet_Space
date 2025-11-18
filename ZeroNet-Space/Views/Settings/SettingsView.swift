//
//  SettingsView.swift
//  ZeroNet-Space
//
//  设置视图
//  应用配置、存储管理、安全设置
//

import SwiftData
import SwiftUI

struct SettingsView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var settings = AppSettings.shared
    @StateObject private var purchaseManager = PurchaseManager.shared

    // MARK: - State

    @EnvironmentObject private var guestModeManager: GuestModeManager
    @State private var showLogoutConfirmation = false
    @State private var showChangePasswordSheet = false
    @State private var showAboutSheet = false
    @State private var showGuestModeSetup = false
    @State private var showGuestModeDisableConfirmation = false
    @State private var storageInfo: StorageInfo?
    @State private var isLoadingStorage = false
    @State private var showClearCacheConfirmation = false
    @State private var currentMediaCount: Int = 0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // 显示设置
                displaySection

                // 导入限制 & 内购
                iapSection

                // 存储管理
                storageSection

                // 安全设置
                securitySection

                // 关于
                aboutSection
            }
            .navigationTitle(String(localized: "settings.title"))
        }
        .confirmationDialog(
            String(localized: "settings.logout.title"), isPresented: $showLogoutConfirmation
        ) {
            Button(String(localized: "settings.logout.confirm"), role: .destructive) {
                authViewModel.logout()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.logout.message"))
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            ChangePasswordView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showAboutSheet) {
            AboutView()
        }
        .sheet(isPresented: $showGuestModeSetup) {
            GuestModeSetupView {
                // 设置完成后启用访客模式
                settings.guestModeEnabled = true
            }
        }
        .confirmationDialog(
            String(localized: "guestMode.disable.title"),
            isPresented: $showGuestModeDisableConfirmation
        ) {
            Button(String(localized: "guestMode.disable.action"), role: .destructive) {
                disableGuestMode()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "guestMode.disable.message"))
        }
        .confirmationDialog(
            String(localized: "settings.clearCache.title"), isPresented: $showClearCacheConfirmation
        ) {
            Button(String(localized: "settings.clearCache.confirm"), role: .destructive) {
                clearCache()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            if let cacheSize = storageInfo?.formattedCacheSize {
                Text(String(format: String(localized: "settings.clearCache.message"), cacheSize))
            }
        }
        .task {
            await loadStorageInfo()
            await loadPurchaseData()
        }
    }

    // MARK: - Organization Section (Removed)
    // 文件夹和标签管理功能已删除

    // MARK: - Display Section

    private var displaySection: some View {
        Section {
            // Grid columns stepper
            Stepper(
                String(format: String(localized: "settings.gridColumns"), settings.gridColumns),
                value: $settings.gridColumns,
                in: 2...5
            )

            // Sort order picker
            Picker(String(localized: "settings.sortBy"), selection: $settings.sortOrder) {
                ForEach(MediaItem.SortOrder.allCases) { order in
                    Text(order.displayName).tag(order)
                }
            }

        } header: {
            Label(String(localized: "settings.display"), systemImage: "rectangle.grid.3x2")
        } footer: {
            Text(String(localized: "settings.display.footer"))
        }
    }

    // MARK: - IAP Section

    private var iapSection: some View {
        Section {
            // Current import count
            HStack {
                Label(String(localized: "iap.importCount.label"), systemImage: "photo.stack")
                Spacer()
                if settings.hasUnlockedUnlimited {
                    Text(String(localized: "iap.unlimited"))
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                } else {
                    Text("\(currentMediaCount) / \(AppConstants.freeImportLimit)")
                        .foregroundColor(
                            currentMediaCount >= AppConstants.freeImportLimit ? .red : .secondary)
                }
            }

            // Unlock unlimited button (if not unlocked)
            if !settings.hasUnlockedUnlimited {
                Button {
                    purchaseUnlimited()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 40, height: 40)

                            Image(systemName: "infinity")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "iap.unlockUnlimited.title"))
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(String(localized: "iap.unlockUnlimited.description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if purchaseManager.isLoading {
                            ProgressView()
                        } else {
                            Text(purchaseManager.getPriceString())
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .disabled(purchaseManager.isLoading)

                // Restore purchases button
                Button {
                    restorePurchases()
                } label: {
                    HStack {
                        Text(String(localized: "iap.restorePurchases"))
                            .font(.subheadline)
                        Spacer()
                        if purchaseManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(purchaseManager.isLoading)
            } else {
                // Already unlocked status
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(String(localized: "iap.alreadyUnlocked"))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

        } header: {
            Label(String(localized: "iap.section.title"), systemImage: "square.and.arrow.down")
        } footer: {
            if let error = purchaseManager.purchaseError {
                Text(error)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            // 存储空间使用
            HStack {
                Label(String(localized: "settings.storage.used"), systemImage: "internaldrive")
                Spacer()
                if isLoadingStorage {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let info = storageInfo {
                    Text(info.formattedTotalUsed)
                        .foregroundColor(.secondary)
                } else {
                    Text(String(localized: "settings.calculating"))
                        .foregroundColor(.secondary)
                }
            }

            // 设备可用空间
            if let info = storageInfo {
                HStack {
                    Label(
                        String(localized: "settings.storage.available"),
                        systemImage: "externaldrive")
                    Spacer()
                    Text(info.formattedAvailableSpace)
                        .foregroundColor(.secondary)
                }
            }

            // 清理缓存
            Button {
                showClearCacheConfirmation = true
            } label: {
                HStack {
                    Label(String(localized: "settings.clearCache.title"), systemImage: "trash")
                    Spacer()
                    if let info = storageInfo {
                        Text(info.formattedCacheSize)
                            .foregroundColor(.secondary)
                    } else {
                        Text("0 MB")
                            .foregroundColor(.secondary)
                    }
                }
            }

        } header: {
            Label(String(localized: "settings.storage.title"), systemImage: "externaldrive")
        } footer: {
            Text(String(localized: "settings.storage.footer"))
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Section {
            // 伪装模式
            NavigationLink {
                DisguiseSettingsView()
            } label: {
                Label(String(localized: "settings.disguiseMode"), systemImage: "theatermasks")
            }

            // 访客模式（仅在主人模式且已购买时显示）
            if guestModeManager.isOwnerMode && purchaseManager.hasUnlockedUnlimited {
                guestModeRow
            }

            // 修改密码
            Button {
                showChangePasswordSheet = true
            } label: {
                Label(String(localized: "settings.changePassword"), systemImage: "key.fill")
                    .foregroundColor(.primary)
            }

            // 退出登录
            Button {
                showLogoutConfirmation = true
            } label: {
                Label(
                    String(localized: "settings.logout.title"),
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
                .foregroundColor(.red)
            }

        } header: {
            Label(String(localized: "settings.security"), systemImage: "lock.shield")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            // 应用版本
            HStack {
                Label(String(localized: "settings.version"), systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            // 关于应用
            Button {
                showAboutSheet = true
            } label: {
                Label(String(localized: "settings.about.app"), systemImage: "app.badge")
                    .foregroundColor(.primary)
            }

            // 离线验证
            NavigationLink {
                NetworkVerificationView()
            } label: {
                Label(String(localized: "network.verification.title"), systemImage: "network.slash")
            }

        } header: {
            Label(String(localized: "settings.about.title"), systemImage: "questionmark.circle")
        }
    }

    // MARK: - Methods

    private func loadStorageInfo() async {
        isLoadingStorage = true
        defer { isLoadingStorage = false }

        storageInfo = await StorageService.shared.getStorageInfo(modelContext: modelContext)
    }

    private func clearCache() {
        Task {
            do {
                let clearedSize = try StorageService.shared.clearCache()
                print("✅ 清理缓存成功: \(StorageService.shared.formatBytes(clearedSize))")

                // 重新加载存储信息
                await loadStorageInfo()
            } catch {
                print("❌ 清理缓存失败: \(error)")
            }
        }
    }

    private func loadPurchaseData() async {
        // Load IAP products
        await purchaseManager.loadProducts()

        // Count current media items
        let descriptor = FetchDescriptor<MediaItem>()
        currentMediaCount = (try? modelContext.fetchCount(descriptor)) ?? 0

        // Sync purchase state with AppSettings
        settings.hasUnlockedUnlimited = purchaseManager.hasUnlockedUnlimited
    }

    private func purchaseUnlimited() {
        Task {
            let success = await purchaseManager.purchase()
            if success {
                // Update settings
                settings.hasUnlockedUnlimited = true
                print("✅ 购买成功，已解锁无限导入")
            }
        }
    }

    private func restorePurchases() {
        Task {
            await purchaseManager.restorePurchases()
            // Update settings
            settings.hasUnlockedUnlimited = purchaseManager.hasUnlockedUnlimited
        }
    }

    // MARK: - Guest Mode

    private var guestModeRow: some View {
        HStack {
            Label(String(localized: "guestMode.title"), systemImage: "person.2.fill")

            Spacer()

            if KeychainService.shared.isGuestPasswordSet() {
                // 已设置访客密码
                Toggle(
                    "",
                    isOn: Binding(
                        get: { settings.guestModeEnabled },
                        set: { newValue in
                            if newValue {
                                settings.guestModeEnabled = true
                            } else {
                                showGuestModeDisableConfirmation = true
                            }
                        }
                    ))
            } else {
                // 未设置访客密码
                Button {
                    showGuestModeSetup = true
                } label: {
                    Text(String(localized: "guestMode.setup.action"))
                        .foregroundColor(.blue)
                }
            }
        }
    }

    private func disableGuestMode() {
        Task {
            do {
                try KeychainService.shared.deleteGuestPassword()
                settings.guestModeEnabled = false
                print("✅ 访客模式已禁用")
            } catch {
                print("❌ 禁用访客模式失败: \(error)")
            }
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isChanging = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(
                        String(localized: "settings.changePassword.current"), text: $currentPassword
                    )
                    SecureField(
                        String(localized: "settings.changePassword.new"), text: $newPassword)
                    SecureField(
                        String(localized: "settings.changePassword.confirm"), text: $confirmPassword
                    )
                } header: {
                    Text(String(localized: "settings.changePassword"))
                } footer: {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    } else {
                        Text(String(localized: "settings.passwordRequirement"))
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(String(localized: "settings.importantReminder"))
                                .fontWeight(.semibold)
                        }

                        Text(String(localized: "settings.changePassword.warning"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button {
                        changePassword()
                    } label: {
                        if isChanging {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                                Text(String(localized: "settings.changingPassword"))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(String(localized: "settings.confirmChange"))
                        }
                    }
                    .disabled(!isValid || isChanging)
                }
            }
            .navigationTitle(String(localized: "settings.changePassword.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                    .disabled(isChanging)
                }
            }
        }
    }

    private var isValid: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && newPassword == confirmPassword
            && newPassword.count >= 6
    }

    private func changePassword() {
        errorMessage = nil

        // 验证当前密码
        guard authViewModel.verifyPassword(currentPassword) else {
            errorMessage = String(localized: "settings.changePassword.error.invalidCurrent")
            return
        }

        // 开始修改密码
        isChanging = true

        Task {
            do {
                try authViewModel.updatePassword(
                    oldPassword: currentPassword,
                    newPassword: newPassword
                )

                await MainActor.run {
                    isChanging = false
                    dismiss()
                }

                print("✅ 密码修改成功")
            } catch {
                await MainActor.run {
                    isChanging = false
                    errorMessage = String(
                        format: String(localized: "settings.changePassword.error.generic"),
                        error.localizedDescription
                    )
                }
                print("❌ 密码修改失败: \(error)")
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 应用图标
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)

                    // 应用名称
                    VStack(spacing: 8) {
                        Text(String(localized: "settings.appName"))
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("ZeroNet Space")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Text(String(localized: "settings.version"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    // 核心Slogan
                    VStack(spacing: 8) {
                        Text(String(localized: "settings.tagline"))
                            .font(.headline)
                            .foregroundColor(.blue)

                        Text(String(localized: "settings.subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)

                    // Feature introduction
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "network.slash",
                            title: String(localized: "settings.feature.offline.title"),
                            description: String(localized: "settings.feature.offline.desc")
                        )

                        FeatureRow(
                            icon: "lock.shield.fill",
                            title: String(localized: "settings.feature.encryption.title"),
                            description: String(localized: "settings.feature.encryption.desc")
                        )

                        FeatureRow(
                            icon: "person.badge.shield.checkmark.fill",
                            title: String(localized: "settings.feature.noAccount.title"),
                            description: String(localized: "settings.feature.noAccount.desc")
                        )

                        FeatureRow(
                            icon: "app.badge.checkmark.fill",
                            title: String(localized: "settings.feature.onePurchase.title"),
                            description: String(localized: "settings.feature.onePurchase.desc")
                        )
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // 版权信息
                    Text(String(localized: "settings.copyright"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "settings.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthenticationViewModel())
}
