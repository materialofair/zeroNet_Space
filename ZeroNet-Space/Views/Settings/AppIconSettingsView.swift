import SwiftUI

struct AppIconSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var auth: AuthenticationViewModel
    @EnvironmentObject private var guest: GuestModeManager
    @StateObject private var icons = AppIconService()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var purchases = PurchaseManager.shared
    @State private var showVIPAlert = false
    @State private var errorMessage: String?

    private var canChange: Bool { auth.isAuthenticated && guest.isOwnerMode }

    var body: some View {
        List {
            Section {
                ForEach(AppIconOption.allCases) { icon in
                    iconRow(icon)
                }
                .disabled(icons.isChanging || purchases.isLoading || !canChange)
            } header: {
                Text(String(localized: "appicon.choose"))
            } footer: {
                Text(String(localized: "appicon.intro"))
            }

            if icons.isChanging {
                Section {
                    ProgressView(String(localized: "appicon.changing"))
                }
            }

            if !settings.isVIP {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown")
                                .foregroundStyle(brandColor)
                            Text(String(localized: "appicon.vip.title"))
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(String(localized: "appicon.vip.summary"))
                            .font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button(String(localized: "appicon.unlock")) { purchase() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            Spacer()
                            Button(String(localized: "iap.restorePurchases")) {
                                Task { await purchases.restorePurchases() }
                            }
                            .buttonStyle(.borderless)
                            .font(.footnote)
                            if purchases.isLoading { ProgressView() }
                        }
                    }
                    .padding(.vertical, 4)
                    .disabled(purchases.isLoading || icons.isChanging || !canChange)
                }
            }

            if let purchaseError = purchases.purchaseError {
                Section {
                    Text(purchaseError).font(.footnote).foregroundStyle(.red)
                }
            }

            Section {
                Text(String(localized: "appicon.footer"))
                    .font(.footnote).foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.insetGrouped)
        .tint(brandColor)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(String(localized: "appicon.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { icons.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { icons.refresh() }
        }
        .alert(String(localized: "appicon.vip.title"), isPresented: $showVIPAlert) {
            Button(String(localized: "appicon.unlock")) { purchase() }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "appicon.vip.message"))
        }
        .alert(String(localized: "common.error"), isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var brandColor: Color {
        Color(.init { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.35, green: 0.78, blue: 0.73, alpha: 1)
                : UIColor(red: 0.02, green: 0.38, blue: 0.38, alpha: 1)
        })
    }

    private func iconRow(_ icon: AppIconOption) -> some View {
        let selected = icons.selectedIconName == icon.iconName
        return Button {
            select(icon)
        } label: {
            HStack(spacing: 12) {
                Image(icon.previewAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(icon.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(icon.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(brandColor)
                } else if icon.requiresVIP {
                    Text("VIP")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("appicon.\(icon.rawValue)")
        .accessibilityLabel(icon.title)
        .accessibilityValue(selected ? String(localized: "appicon.selected") : (icon.requiresVIP ? "VIP" : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func select(_ icon: AppIconOption) {
        guard canChange, !icons.isChanging, !purchases.isLoading else { return }
        guard icons.selectedIconName != icon.iconName else { return }
        guard !icon.requiresVIP || settings.isVIP else {
            showVIPAlert = true
            return
        }
        Task {
            do {
                try await icons.select(icon, isVIP: settings.isVIP)
            } catch let error as AppIconService.IconError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = String(localized: "appicon.error.failed")
            }
        }
    }

    private func purchase() {
        guard canChange, !purchases.isLoading else { return }
        Task { _ = await purchases.purchase() }
    }
}
