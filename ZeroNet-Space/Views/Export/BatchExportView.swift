/*@ai:risk=3|deps=ExportService,MediaItem|lines=400*/
//
//  BatchExportView.swift
//  ZeroNet-Space
//
//  批量导出视图
//  选择文件并导出到系统分享界面
//

import SwiftData
import SwiftUI

struct BatchExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    @Query private var allItems: [MediaItem]

    @State private var selectedItems: Set<UUID> = []
    @State private var isExporting: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var exportedURLs: [URL] = []
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var exportTotalCount: Int = 0
    @State private var exportedCount: Int = 0
    @State private var exportStatusText: String = ""

    private let exportService = ExportService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isExporting {
                    exportingView
                } else {
                    selectionView
                }
            }
            .navigationTitle(String(localized: "export.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                    .disabled(isExporting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.export")) {
                        startExport()
                    }
                    .disabled(selectedItems.isEmpty || isExporting)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: exportedURLs)
            }
            .alert(String(localized: "export.failed"), isPresented: $showError) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Selection View

    private var selectionView: some View {
        VStack(spacing: 0) {
            // 选择统计
            HStack {
                Text(String(format: String(localized: "export.selectedCount"), selectedItems.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if !selectedItems.isEmpty {
                    Button {
                        selectedItems.removeAll()
                    } label: {
                        Text(String(localized: "export.clear"))
                            .font(.subheadline)
                    }
                }

                Button {
                    selectAll()
                } label: {
                    Text(
                        selectedItems.count == allItems.count
                            ? String(localized: "export.deselectAll")
                            : String(localized: "common.selectAll")
                    )
                    .font(.subheadline)
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))

            Divider()

            // 文件列表
            if allItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(allItems) { item in
                            ExportItemRow(
                                item: item,
                                isSelected: selectedItems.contains(item.id)
                            ) {
                                toggleSelection(item)
                            }

                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Exporting View

    private var exportingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 进度指示器
            ProgressView(value: exportProgressValue, total: 1.0) {
                Text(
                    exportStatusText.isEmpty
                        ? String(localized: "filePreview.exporting") : exportStatusText
                )
                .font(.headline)
            } currentValueLabel: {
                Text("\(Int(exportProgressValue * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 300)

            Text(String(localized: "export.decrypting"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(String(localized: "export.empty.title"))
                .font(.title3)
                .fontWeight(.medium)

            Text(String(localized: "export.empty.subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func toggleSelection(_ item: MediaItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func selectAll() {
        if selectedItems.count == allItems.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(allItems.map { $0.id })
        }
    }

    private func startExport() {
        guard !selectedItems.isEmpty else { return }

        // 获取选中的媒体项
        let itemsToExport = allItems.filter { selectedItems.contains($0.id) }

        // 开始导出
        isExporting = true
        exportTotalCount = itemsToExport.count
        exportedCount = 0
        exportStatusText =
            exportTotalCount > 0
            ? String(
                format: String(localized: "export.decryptingProgress"),
                1,
                exportTotalCount)
            : ""

        // 获取当前密码
        guard let password = authViewModel.sessionPassword else {
            errorMessage = String(localized: "export.error.noPassword")
            showError = true
            isExporting = false
            return
        }

        // 执行导出
        exportService.exportItems(
            itemsToExport,
            password: password,
            progressHandler: { processed, total in
                DispatchQueue.main.async {
                    self.exportedCount = processed
                    if processed < total {
                        self.exportStatusText = String(
                            format: String(localized: "export.decryptingProgress"),
                            processed + 1,
                            total)
                    } else {
                        self.exportStatusText = String(localized: "export.preparingShare")
                    }
                }
            }
        ) { result in
            switch result {
            case .success(let urls):
                exportedURLs = urls
                exportedCount = exportTotalCount

                // 延迟显示分享界面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isExporting = false
                    showShareSheet = true
                }

            case .failure(let error):
                isExporting = false
                exportedCount = 0
                exportTotalCount = 0
                exportStatusText = ""
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private var exportProgressValue: Double {
        guard exportTotalCount > 0 else { return 0 }
        return Double(exportedCount) / Double(exportTotalCount)
    }
}

// MARK: - Export Item Row

struct ExportItemRow: View {
    let item: MediaItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 选择标记
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)

                // 文件图标
                Image(systemName: item.type.iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)

                // 文件信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack {
                        Text(item.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(item.formattedFileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = ExportService.createShareController(for: items as! [URL])
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

#Preview {
    BatchExportView()
        .modelContainer(for: MediaItem.self, inMemory: true)
        .environmentObject(AuthenticationViewModel())
}
