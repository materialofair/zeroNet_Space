//
//  GridItemView.swift
//  ZeroNet-Space
//
//  网格项视图
//  展示媒体缩略图
//

import SwiftUI

struct GridItemView: View {

    // MARK: - Properties

    let mediaItem: MediaItem
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // 背景和缩略图
                thumbnailView(size: geometry.size)

                // 渐变遮罩
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 信息叠加层
                overlayInfo

                // 选择模式标记
                if isSelectionMode {
                    selectionOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue, lineWidth: isSelected ? 3 : 0)
            )
        }
        .aspectRatio(1, contentMode: .fill)
        .onAppear {
            loadThumbnailIfNeeded()
        }
    }

    // MARK: - Thumbnail View

    @ViewBuilder
    private func thumbnailView(size: CGSize) -> some View {
        if let image = thumbnailImage {
            // 显示缩略图
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
        } else if mediaItem.thumbnailData != nil {
            placeholderView
                .overlay {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
        } else {
            // 占位符
            placeholderView
        }
    }

    // MARK: - Placeholder View

    private var placeholderView: some View {
        ZStack {
            // 背景颜色
            mediaItem.type.iconColor.opacity(0.2)

            // 类型图标
            VStack(spacing: 8) {
                Image(systemName: mediaItem.type.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(mediaItem.type.iconColor)

                Text(mediaItem.fileExtension)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Overlay Info

    private var overlayInfo: some View {
        HStack(alignment: .bottom) {
            // 类型图标
            Image(systemName: mediaItem.type.iconName)
                .font(.caption)
                .foregroundColor(.white)
                .padding(6)
                .background(Circle().fill(mediaItem.type.iconColor))

            Spacer()

            // 视频时长
            if mediaItem.type == .video, let duration = mediaItem.formattedDuration {
                Text(duration)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
            }
        }
        .padding(8)
    }

    // MARK: - Selection Overlay

    private var selectionOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .white)
                    .padding(8)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func loadThumbnailIfNeeded() {
        guard thumbnailImage == nil,
            !isLoadingThumbnail,
            let thumbnailData = mediaItem.thumbnailData
        else {
            return
        }

        isLoadingThumbnail = true

        DispatchQueue.global(qos: .userInitiated).async {
            let image = UIImage(data: thumbnailData)

            DispatchQueue.main.async {
                self.thumbnailImage = image
                self.isLoadingThumbnail = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleItem = MediaItem(
        fileName: "Sample",
        fileExtension: ".jpg",
        fileSize: 1_024_000,
        type: .photo,
        encryptedPath: "/path/to/file",
        thumbnailData: nil,
        width: 1920,
        height: 1080
    )

    return GridItemView(mediaItem: sampleItem)
        .frame(width: 150, height: 150)
        .padding()
}
