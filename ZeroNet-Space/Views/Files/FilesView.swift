//
//  FilesView.swift
//  ZeroNet-Space
//
//  文件视图
//  管理和预览各种文件类型（PDF、文本等）
//

import SwiftData
import SwiftUI

struct FilesView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    // 只查询文件类型的媒体
    @Query(
        filter: #Predicate<MediaItem> { item in
            item.typeRawValue == "document"
        },
        sort: \MediaItem.createdAt,
        order: .reverse
    )
    private var files: [MediaItem]

    // MARK: - State

    @EnvironmentObject private var guestModeManager: GuestModeManager
    @State private var showImportView = false
    @State private var selectedFile: MediaItem?
    @State private var searchText = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 访客模式下始终显示空状态
                if guestModeManager.isGuestMode || files.isEmpty {
                    emptyStateView
                } else {
                    fileListView
                }
            }
            .navigationTitle(String(localized: "files.title"))
            .searchable(text: $searchText, prompt: String(localized: "files.search.placeholder"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 访客模式下隐藏导入按钮
                    if guestModeManager.isOwnerMode {
                        Button {
                            showImportView = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
            .sheet(isPresented: $showImportView) {
                ImportButtonsView(onImportComplete: { items in
                    print("✅ 导入完成: \(items.count) 个文件")
                })
                .environment(\.modelContext, modelContext)
                .environmentObject(authViewModel)
            }
            .sheet(item: $selectedFile) { file in
                NavigationStack {
                    MediaDetailView(mediaItem: file)
                }
                .environment(\.modelContext, modelContext)
                .environmentObject(authViewModel)
            }
            .task {
                cleanupInvalidFiles()
            }
        }
    }

    // MARK: - Cleanup

    /// 清理失效的文件记录
    private func cleanupInvalidFiles() {
        let storage = FileStorageService.shared
        var removedCount = 0

        for file in files {
            if !storage.fileExists(path: file.encryptedPath) {
                modelContext.delete(file)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            do {
                try modelContext.save()
                print("🗑️ 已清理 \(removedCount) 条失效的文件记录")
            } catch {
                print("❌ 清理失效记录失败: \(error)")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // 渐变图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .teal.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(String(localized: "files.empty.title"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "files.empty.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                showImportView = true
            } label: {
                Label(String(localized: "files.import.start"), systemImage: "doc.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.green, .teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - File List

    private var fileListView: some View {
        List {
            ForEach(filteredFiles) { file in
                FileRowView(file: file)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFile = file
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteFile(file)
                        } label: {
                            Label(String(localized: "common.delete"), systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Computed Properties

    private var filteredFiles: [MediaItem] {
        if searchText.isEmpty {
            return files
        }
        return files.filter { file in
            file.fileName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Methods

    private func deleteFile(_ file: MediaItem) {
        modelContext.delete(file)
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let file: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            // 文件类型图标
            fileIcon
                .font(.title2)
                .foregroundStyle(fileIconGradient)
                .frame(width: 44, height: 44)
                .background(fileIconGradient.opacity(0.1))
                .cornerRadius(10)

            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Text(file.fileExtension.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(fileIconGradient)
                        .cornerRadius(6)

                    Text(formatFileSize(file.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatDate(file.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var fileIcon: Image {
        let ext = file.fileExtension.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        switch ext {
        case "pdf":
            return Image(systemName: "doc.text.fill")
        case "txt", "md":
            return Image(systemName: "doc.plaintext.fill")
        case "zip", "rar":
            return Image(systemName: "doc.zipper.fill")
        case "doc", "docx":
            return Image(systemName: "doc.richtext.fill")
        case "xls", "xlsx":
            return Image(systemName: "tablecells.fill")
        default:
            return Image(systemName: "doc.fill")
        }
    }

    private var fileIconGradient: LinearGradient {
        let ext = file.fileExtension.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        switch ext {
        case "pdf":
            return LinearGradient(
                colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "txt", "md":
            return LinearGradient(
                colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "zip", "rar":
            return LinearGradient(
                colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(
                colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    FilesView()
        .modelContainer(for: MediaItem.self, inMemory: true)
        .environmentObject(AuthenticationViewModel())
}
