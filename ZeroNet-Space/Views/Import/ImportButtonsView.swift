//
//  ImportButtonsView.swift
//  ZeroNet-Space
//
//  导入按钮视图
//  提供照片和文件导入选项
//

import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImportButtonsView: View {

    // MARK: - Properties

    @StateObject private var viewModel = ImportViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    let onImportComplete: ([MediaItem]) -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // 导入选项（始终显示）
                importOptionsView
                    .opacity(viewModel.isImporting ? 0.3 : 1.0)
            }
            .loadingOverlay(
                isShowing: viewModel.isImporting,
                message: viewModel.progressText,
                progress: viewModel.importProgress?.percentage
            )
            .navigationTitle(String(localized: "import.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !viewModel.isImporting {
                        Button(String(localized: "common.cancel")) {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showPhotoPicker) {
                PhotoPickerRepresentable(
                    isPresented: $viewModel.showPhotoPicker,
                    selectionLimit: 0,
                    filter: .any(of: [.images, .videos])
                ) { results in
                    viewModel.importFromPhotoLibrary(results: results)
                }
            }
            .sheet(isPresented: $viewModel.showFilePicker) {
                DocumentPickerRepresentable(
                    isPresented: $viewModel.showFilePicker,
                    contentTypes: [.item],
                    allowsMultipleSelection: true
                ) { urls in
                    viewModel.importFromFiles(urls: urls)
                }
            }
            .alert(
                String(localized: "import.failed"),
                isPresented: .constant(viewModel.errorMessage != nil)
            ) {
                Button(String(localized: "common.ok")) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .alert(
                String(localized: "iap.limitReached.title"),
                isPresented: $viewModel.showLimitAlert
            ) {
                Button(String(localized: "iap.unlockUnlimited.button")) {
                    // Navigate to settings for purchase
                    viewModel.showLimitAlert = false
                }
                Button(String(localized: "common.cancel"), role: .cancel) {
                    viewModel.showLimitAlert = false
                }
            } message: {
                Text(viewModel.limitAlertMessage)
            }
            .onAppear {
                print("🔧 ImportButtonsView 初始化...")
                print("📊 ModelContext: \(modelContext)")

                viewModel.modelContext = modelContext
                viewModel.authViewModel = authViewModel
                viewModel.onImportComplete = { items in
                    onImportComplete(items)
                    // 延迟关闭，显示成功消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                }

                print("✅ ImportViewModel 已配置完成")
            }
        }
    }

    // MARK: - Import Options View

    private var importOptionsView: some View {
        VStack(spacing: 20) {
            // 标题说明
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text(String(localized: "import.selectMethod.title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(String(localized: "import.selectMethod.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            // Import limit banner
            if !viewModel.appSettings.hasUnlockedUnlimited {
                importLimitBanner
            }

            Spacer()

            // 导入选项
            VStack(spacing: 16) {
                // 从相册导入
                ImportOptionButton(
                    icon: "photo.on.rectangle.angled",
                    title: String(localized: "import.fromPhotos.title"),
                    subtitle: String(localized: "import.fromPhotos.subtitle"),
                    color: .blue
                ) {
                    viewModel.selectPhotos()
                }

                // 从文件导入
                ImportOptionButton(
                    icon: "folder",
                    title: String(localized: "import.fromFiles.title"),
                    subtitle: String(localized: "import.fromFiles.subtitle"),
                    color: .orange
                ) {
                    viewModel.selectFiles()
                }
            }
            .padding(.horizontal)

            if viewModel.isImporting {
                Button {
                    viewModel.cancelImport()
                    dismiss()
                } label: {
                    Label(String(localized: "import.stop"), systemImage: "stop.circle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(12)
                }
                .padding(.top, 12)
            }

            Spacer()

            // 提示信息
            VStack(alignment: .leading, spacing: 8) {
                Label(String(localized: "import.formats.title"), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(localized: "import.formats.photos"))
                Text(String(localized: "import.formats.videos"))
                Text(String(localized: "import.formats.documents"))

                Divider()
                    .padding(.vertical, 4)

                // Network notice
                Text(String(localized: "network.import.cloud.notice"))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.orange)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Importing View

    private var importingView: some View {
        VStack(spacing: 30) {
            Spacer()

            // 动画图标
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: viewModel.progressPercentage)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: viewModel.progressPercentage)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }

            // 进度信息
            VStack(spacing: 12) {
                Text(viewModel.progressText)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let progress = viewModel.importProgress {
                    Text("\(Int(progress.percentage * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            // 成功消息
            if viewModel.importedCount > 0 && !viewModel.isImporting {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text(String(localized: "import.success.title"))
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(
                        String(
                            format: String(localized: "import.success.count"),
                            viewModel.importedCount)
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
    }

    // MARK: - Import Limit Banner

    private var importLimitBanner: some View {
        let remaining = viewModel.getRemainingImports()
        let currentCount = viewModel.getCurrentMediaCount()
        let isNearLimit = remaining <= 10 && remaining > 0

        return HStack(spacing: 12) {
            Image(systemName: remaining > 0 ? "info.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(remaining > 0 ? (isNearLimit ? .orange : .blue) : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "iap.importCount.label"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("\(currentCount)")
                        .font(.headline)
                        .foregroundColor(remaining > 0 ? .primary : .red)
                    Text("/")
                        .foregroundColor(.secondary)
                    Text("\(AppConstants.freeImportLimit)")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if remaining > 0 {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(String(localized: "iap.remaining.label"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(remaining)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isNearLimit ? .orange : .blue)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    remaining > 0
                        ? (isNearLimit ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                        : Color.red.opacity(0.1))
        )
        .padding(.horizontal)
    }
}

// MARK: - Import Option Button

struct ImportOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(color)
                }

                // 文字
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 箭头
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ImportButtonsView { items in
        print("Imported \(items.count) items")
    }
    .modelContainer(for: [MediaItem.self])
}
