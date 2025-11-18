//
//  PhotoPickerRepresentable.swift
//  ZeroNet-Space
//
//  PHPickerViewController的SwiftUI桥接
//  用于选择照片和视频
//

import PhotosUI
import SwiftUI

/// PHPicker结果
struct PhotoPickerResult {
    let itemProvider: NSItemProvider
    let assetIdentifier: String?
}

/// PhotoPicker SwiftUI表示
struct PhotoPickerRepresentable: UIViewControllerRepresentable {

    // MARK: - Properties

    @Binding var isPresented: Bool
    let selectionLimit: Int
    let filter: PHPickerFilter
    let onSelect: ([PHPickerResult]) -> Void

    // MARK: - Initialization

    init(
        isPresented: Binding<Bool>,
        selectionLimit: Int = 0,  // 0 = 无限制
        filter: PHPickerFilter = .any(of: [.images, .videos]),
        onSelect: @escaping ([PHPickerResult]) -> Void
    ) {
        self._isPresented = isPresented
        self.selectionLimit = selectionLimit
        self.filter = filter
        self.onSelect = onSelect
    }

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = selectionLimit
        configuration.filter = filter
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // 不需要更新
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerRepresentable

        init(_ parent: PhotoPickerRepresentable) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false

            if !results.isEmpty {
                parent.onSelect(results)
            }
        }
    }
}

// MARK: - Document Picker Representable

/// 文档选择器SwiftUI表示
struct DocumentPickerRepresentable: UIViewControllerRepresentable {

    // MARK: - Properties

    @Binding var isPresented: Bool
    let contentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onSelect: ([URL]) -> Void

    // MARK: - Initialization

    init(
        isPresented: Binding<Bool>,
        contentTypes: [UTType] = [.item],
        allowsMultipleSelection: Bool = true,
        onSelect: @escaping ([URL]) -> Void
    ) {
        self._isPresented = isPresented
        self.contentTypes = contentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onSelect = onSelect
    }

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController, context: Context
    ) {
        // 不需要更新
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerRepresentable

        init(_ parent: DocumentPickerRepresentable) {
            self.parent = parent
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
        ) {
            parent.isPresented = false
            parent.onSelect(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}
