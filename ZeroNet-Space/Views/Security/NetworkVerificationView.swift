//
//  NetworkVerificationView.swift
//  零网络空间 (ZeroNet Space)
//
//  无网络验证界面 - 展示应用的零网络特性
//  核心差异化功能：向用户证明应用完全离线
//

import SwiftUI

struct NetworkVerificationView: View {

    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // 顶部标题
                VStack(spacing: 12) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 20)

                    Text(String(localized: "network.verification.title"))
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(String(localized: "network.verification.subtitle"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // 核心承诺
                corePromiseCard

                // Tab选择器
                Picker(String(localized: "network.verification.method"), selection: $selectedTab) {
                    Text(String(localized: "network.tab.permissions")).tag(0)
                    Text(String(localized: "network.tab.technical")).tag(1)
                    Text(String(localized: "network.tab.dataFlow")).tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // 根据Tab显示不同内容
                Group {
                    switch selectedTab {
                    case 0:
                        permissionsVerificationView
                    case 1:
                        technicalProofView
                    case 2:
                        dataFlowView
                    default:
                        permissionsVerificationView
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(String(localized: "network.offline.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 核心承诺卡片

    private var corePromiseCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main promise section
            Label(String(localized: "network.promises.title"), systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 12) {
                PromiseRow(
                    icon: "network.slash",
                    title: String(localized: "network.promise.zero.network"),
                    description: String(localized: "network.promise.zero.network.desc")
                )

                PromiseRow(
                    icon: "arrow.up.circle.fill",
                    title: String(localized: "network.promise.zero.upload"),
                    description: String(localized: "network.promise.zero.upload.desc")
                )

                PromiseRow(
                    icon: "eye.slash.fill",
                    title: String(localized: "network.promise.zero.tracking"),
                    description: String(localized: "network.promise.zero.tracking.desc")
                )

                PromiseRow(
                    icon: "shield.checkmark.fill",
                    title: String(localized: "network.promise.zero.risk"),
                    description: String(localized: "network.promise.zero.risk.desc")
                )
            }

            Divider()
                .padding(.vertical, 8)

            // Normal usage promise
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "network.promise.title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(String(localized: "network.promise.normal"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .padding(.vertical, 8)

            // Exceptions section
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    String(localized: "network.promise.exceptions"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)

                Text(String(localized: "network.promise.exceptions.detail"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // IAP notice
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text(String(localized: "network.iap.notice"))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - 权限验证视图

    private var permissionsVerificationView: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text(String(localized: "network.permissions.title"))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // 已请求的权限
                SectionCard(title: String(localized: "network.permissions.requested")) {
                    VStack(spacing: 12) {
                        PermissionRow(
                            icon: "photo",
                            name: String(localized: "network.permission.photos"),
                            purpose: String(localized: "network.permission.photos.purpose"),
                            status: .allowed
                        )

                        Divider()

                        Text(String(localized: "network.permissions.onlyOne"))
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                }

                // 未请求的权限
                SectionCard(title: String(localized: "network.permissions.notRequested")) {
                    VStack(spacing: 8) {
                        PermissionRow(
                            icon: "network",
                            name: String(localized: "network.permission.network"),
                            purpose: String(localized: "network.permission.notNeeded"),
                            status: .denied
                        )

                        Divider()

                        PermissionRow(
                            icon: "location",
                            name: String(localized: "network.permission.location"),
                            purpose: String(localized: "network.permission.notNeeded"),
                            status: .denied
                        )

                        Divider()

                        PermissionRow(
                            icon: "mic",
                            name: String(localized: "network.permission.microphone"),
                            purpose: String(localized: "network.permission.notNeeded"),
                            status: .denied
                        )

                        Divider()

                        PermissionRow(
                            icon: "camera",
                            name: String(localized: "network.permission.camera"),
                            purpose: String(localized: "network.permission.notNeeded"),
                            status: .denied
                        )

                        Divider()

                        PermissionRow(
                            icon: "antenna.radiowaves.left.and.right",
                            name: String(localized: "network.permission.bluetooth"),
                            purpose: String(localized: "network.permission.notNeeded"),
                            status: .denied
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - 技术证明视图

    private var technicalProofView: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text(String(localized: "network.technical.title"))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // 加密技术
                SectionCard(title: String(localized: "network.encryption.title")) {
                    VStack(alignment: .leading, spacing: 12) {
                        TechDetailRow(
                            label: String(localized: "network.encryption.algorithm"),
                            value: "AES-256-GCM"
                        )

                        TechDetailRow(
                            label: String(localized: "network.encryption.keyDerivation"),
                            value: String(localized: "network.encryption.pbkdf2")
                        )

                        TechDetailRow(
                            label: String(localized: "network.encryption.hash"),
                            value: "SHA-256"
                        )

                        TechDetailRow(
                            label: String(localized: "network.encryption.keyStorage"),
                            value: "iOS Keychain"
                        )

                        Divider()

                        Text(String(localized: "network.technical.encryption"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 数据存储
                SectionCard(title: String(localized: "network.storage.title")) {
                    VStack(alignment: .leading, spacing: 12) {
                        TechDetailRow(
                            label: String(localized: "network.storage.location"),
                            value: String(localized: "network.storage.sandbox")
                        )

                        TechDetailRow(
                            label: String(localized: "network.storage.database"),
                            value: String(localized: "network.storage.swiftdata")
                        )

                        TechDetailRow(
                            label: String(localized: "network.storage.encryption"),
                            value: String(localized: "network.storage.encryption.yes")
                        )

                        TechDetailRow(
                            label: String(localized: "network.storage.cloudSync"),
                            value: String(localized: "network.storage.cloudSync.disabled")
                        )

                        Divider()

                        Text(String(localized: "network.technical.storage"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 代码审计
                SectionCard(title: String(localized: "network.code.guarantees.title")) {
                    VStack(alignment: .leading, spacing: 12) {
                        CheckmarkRow(text: String(localized: "network.code.noURLSession"))
                        CheckmarkRow(text: String(localized: "network.code.noThirdPartySDK"))
                        CheckmarkRow(text: String(localized: "network.code.noAnalytics"))
                        CheckmarkRow(text: String(localized: "network.code.noAds"))
                        CheckmarkRow(text: String(localized: "network.code.noCloudStorage"))
                        CheckmarkRow(text: String(localized: "network.code.noNetworkPermission"))

                        Divider()

                        Text(String(localized: "network.technical.guarantee"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)

                        Text(
                            String(localized: "network.cloudImportNotice")
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - 数据流向视图

    private var dataFlowView: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text(String(localized: "network.dataFlow.title"))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // 数据导入流程
                SectionCard(title: String(localized: "network.dataFlow.import.title")) {
                    VStack(alignment: .leading, spacing: 16) {
                        FlowStep(
                            number: 1,
                            title: String(localized: "network.dataFlow.selectFile"),
                            description: String(localized: "network.dataFlow.selectFromPhotos"),
                            icon: "photo.on.rectangle.angled"
                        )

                        FlowArrow()

                        FlowStep(
                            number: 2,
                            title: String(localized: "network.dataFlow.readLocal"),
                            description: String(localized: "network.dataFlow.readLocal.description"),
                            icon: "arrow.down.circle"
                        )

                        FlowArrow()

                        FlowStep(
                            number: 3,
                            title: String(localized: "network.dataFlow.encrypt"),
                            description: String(localized: "network.dataFlow.encrypt.desc"),
                            icon: "lock.fill"
                        )

                        FlowArrow()

                        FlowStep(
                            number: 4,
                            title: String(localized: "network.dataFlow.store"),
                            description: String(localized: "network.dataFlow.store.desc"),
                            icon: "internaldrive"
                        )

                        Divider()
                            .padding(.vertical, 8)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(String(localized: "network.dataFlow.local"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Data access flow
                SectionCard(title: String(localized: "network.dataFlow.accessFlow")) {
                    VStack(alignment: .leading, spacing: 16) {
                        FlowStep(
                            number: 1,
                            title: String(localized: "network.dataFlow.enterPassword"),
                            description: String(localized: "network.dataFlow.enterPassword.desc"),
                            icon: "key.fill"
                        )

                        FlowArrow()

                        FlowStep(
                            number: 2,
                            title: String(localized: "network.dataFlow.readEncrypted"),
                            description: String(localized: "network.dataFlow.readEncrypted.desc"),
                            icon: "doc.fill"
                        )

                        FlowArrow()

                        FlowStep(
                            number: 3,
                            title: String(localized: "network.dataFlow.decrypt"),
                            description: String(localized: "network.dataFlow.decrypt.desc"),
                            icon: "lock.open.fill"
                        )

                        FlowArrow()

                        FlowStep(
                            number: 4,
                            title: String(localized: "network.dataFlow.display"),
                            description: String(localized: "network.dataFlow.display.desc"),
                            icon: "eye.fill"
                        )

                        Divider()
                            .padding(.vertical, 8)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(String(localized: "network.dataFlow.memory"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Comparison section
                SectionCard(title: String(localized: "network.comparison.title")) {
                    VStack(alignment: .leading, spacing: 12) {
                        ComparisonRow(
                            feature: String(localized: "network.comparison.dataStorage"),
                            traditional: String(localized: "network.comparison.traditional.upload"),
                            zeronet: String(localized: "network.comparison.zeronet.storage"),
                            isGood: true
                        )

                        Divider()

                        ComparisonRow(
                            feature: String(localized: "network.comparison.encryption"),
                            traditional: String(
                                localized: "network.comparison.traditional.encryption"),
                            zeronet: String(localized: "network.comparison.zeronet.encryption"),
                            isGood: true
                        )

                        Divider()

                        ComparisonRow(
                            feature: String(localized: "network.comparison.privacy"),
                            traditional: String(
                                localized: "network.comparison.traditional.privacy"),
                            zeronet: String(localized: "network.comparison.zeronet.privacy"),
                            isGood: true
                        )

                        Divider()

                        ComparisonRow(
                            feature: String(localized: "network.comparison.security"),
                            traditional: String(
                                localized: "network.comparison.traditional.security"),
                            zeronet: String(localized: "network.comparison.zeronet.security"),
                            isGood: true
                        )

                        Divider()

                        ComparisonRow(
                            feature: String(localized: "network.comparison.dataControl"),
                            traditional: String(
                                localized: "network.comparison.traditional.dataControl"),
                            zeronet: String(localized: "network.comparison.zeronet.dataControl"),
                            isGood: true
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 辅助组件

struct PromiseRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

enum PermissionStatus {
    case allowed
    case denied
}

struct PermissionRow: View {
    let icon: String
    let name: String
    let purpose: String
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(status == .allowed ? .blue : .gray)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(purpose)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: status == .allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status == .allowed ? .green : .red)
        }
    }
}

struct TechDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct CheckmarkRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct FlowStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)

                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct FlowArrow: View {
    var body: some View {
        HStack {
            Spacer()
                .frame(width: 20)

            Image(systemName: "arrow.down")
                .font(.caption)
                .foregroundColor(.blue)

            Spacer()
        }
    }
}

struct ComparisonRow: View {
    let feature: String
    let traditional: String
    let zeronet: String
    let isGood: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(feature)
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "network.comparison.traditional"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)

                        Text(traditional)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "settings.appName"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)

                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)

                        Text(zeronet)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NetworkVerificationView()
    }
}
