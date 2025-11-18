//
//  GalleryView.swift
//  ZeroNet-Space
//
//  主图库界面
//  网格展示所有导入的媒体
//

import SwiftData
import SwiftUI

struct GalleryView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Query private var mediaItems: [MediaItem]

    // MARK: - State

    @StateObject private var viewModel = GalleryViewModel()
    @StateObject private var settings = AppSettings.shared
    @EnvironmentObject private var guestModeManager: GuestModeManager
    @State private var searchText = ""
    @State private var isSearching = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 访客模式下始终显示空状态
                if guestModeManager.isGuestMode || mediaItems.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 媒体网格
                    mediaGridView
                }
            }
            .navigationTitle(String(localized: "gallery.title"))
            .searchable(
                text: $searchText,
                isPresented: $isSearching,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: String(localized: "gallery.search.placeholder")
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isSelectionMode {
                        selectAllButton
                    } else {
                        sortButton
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSelectionMode {
                        cancelButton
                    } else {
                        HStack(spacing: 16) {
                            selectButton
                            addButton
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isSelectionMode && !viewModel.selectedItemIDs.isEmpty {
                    batchActionsToolbar
                }
            }
            .sheet(isPresented: $viewModel.showImportView) {
                ImportButtonsView { items in
                    print("✅ 导入完成: \(items.count) 个文件")
                }
                .environment(\.modelContext, modelContext)
                .environmentObject(authViewModel)
            }
            .confirmationDialog(
                String(localized: "gallery.delete.title"),
                isPresented: $viewModel.showDeleteConfirmation
            ) {
                Button(String(localized: "common.delete"), role: .destructive) {
                    viewModel.confirmDelete()
                }
                Button(String(localized: "common.cancel"), role: .cancel) {
                    viewModel.cancelDelete()
                }
            } message: {
                if let item = viewModel.mediaItemToDelete {
                    Text(String(format: String(localized: "gallery.delete.message"), item.fileName))
                }
            }
            .alert(
                String(localized: "common.error"),
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
                    // User can navigate to settings to purchase
                    viewModel.showLimitAlert = false
                }
                Button(String(localized: "common.cancel"), role: .cancel) {
                    viewModel.showLimitAlert = false
                }
            } message: {
                Text(String(localized: "iap.limitReached.message"))
            }
            .onAppear {
                viewModel.modelContext = modelContext
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.gray)

            Text(String(localized: "gallery.empty.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(localized: "gallery.empty.subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // 访客模式下隐藏导入按钮
            if guestModeManager.isOwnerMode {
                Button(action: {
                    viewModel.showImport()
                }) {
                    Label(String(localized: "files.import.start"), systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top)
            }

            Spacer()
        }
    }

    // MARK: - Media Grid

    private var mediaGridView: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: AppConstants.gridSpacing),
                    count: settings.gridColumns
                ),
                spacing: AppConstants.gridSpacing
            ) {
                ForEach(sortedMediaItems) { item in
                    if viewModel.isSelectionMode {
                        // 选择模式：点击切换选择状态
                        Button {
                            viewModel.toggleSelection(for: item)
                        } label: {
                            GridItemView(
                                mediaItem: item,
                                isSelectionMode: true,
                                isSelected: viewModel.selectedItemIDs.contains(item.id)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 正常模式：导航到详情
                        NavigationLink(
                            destination: MediaDetailView(mediaItem: item)
                                .environmentObject(authViewModel)
                                .onAppear {
                                    print(
                                        "🚀 NavigationLink destination appeared for: \(item.fullFileName)"
                                    )
                                    print("🚀 传递的MediaItem数据:")
                                    print("   - ID: \(item.id)")
                                    print("   - 文件名: \(item.fullFileName)")
                                    print("   - 加密路径: \(item.encryptedPath)")
                                    print("   - 尺寸: \(item.width ?? 0)×\(item.height ?? 0)")
                                    print("   - 时长: \(item.duration ?? 0)秒")
                                    print(
                                        "   - 缩略图: \(item.thumbnailData != nil ? "有(\(item.thumbnailData!.count) bytes)" : "无")"
                                    )
                                }
                        ) {
                            GridItemView(mediaItem: item)
                                .onTapGesture {
                                    print("👆 GridItemView tapped: \(item.fullFileName)")
                                }
                        }
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                print("🔗 NavigationLink tapped: \(item.fullFileName)")
                            }
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteMediaItem(item)
                            } label: {
                                Label(String(localized: "common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Toolbar Items

    private var sortButton: some View {
        Menu {
            ForEach(MediaItem.SortOrder.allCases) { sortOrder in
                Button {
                    viewModel.changeSortOrder(to: sortOrder)
                } label: {
                    HStack {
                        Text(sortOrder.displayName)
                        if sortOrder == viewModel.sortOrder {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }

    private var addButton: some View {
        Button(action: {
            viewModel.showImport()
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
        }
    }

    private var selectButton: some View {
        Button(action: {
            viewModel.toggleSelectionMode()
        }) {
            Text(String(localized: "common.select"))
        }
    }

    private var selectAllButton: some View {
        Button(action: {
            if viewModel.selectedItemIDs.count == mediaItems.count {
                viewModel.deselectAll()
            } else {
                viewModel.selectAll(mediaItems)
            }
        }) {
            Text(
                viewModel.selectedItemIDs.count == mediaItems.count
                    ? String(localized: "export.deselectAll")
                    : String(localized: "common.selectAll"))
        }
    }

    private var cancelButton: some View {
        Button(action: {
            viewModel.toggleSelectionMode()
        }) {
            Text(String(localized: "common.cancel"))
        }
    }

    // MARK: - Batch Actions Toolbar

    private var batchActionsToolbar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 20) {
                Text(
                    String(
                        format: String(localized: "gallery.selectedCount"),
                        viewModel.selectedItemIDs.count)
                )
                .font(.subheadline)
                .foregroundColor(.secondary)

                Spacer()

                Button(role: .destructive) {
                    viewModel.deleteSelectedItems(mediaItems)
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Computed Properties

    private var sortedMediaItems: [MediaItem] {
        var items = mediaItems

        // 应用搜索过滤
        if !searchText.isEmpty {
            items = viewModel.search(items, query: searchText)
        }

        // 应用排序
        let descriptor = viewModel.sortOrder.sortDescriptor
        return items.sorted(using: descriptor)
    }
}

// MARK: - Preview

#Preview {
    GalleryView()
        .modelContainer(for: MediaItem.self, inMemory: true)
}
