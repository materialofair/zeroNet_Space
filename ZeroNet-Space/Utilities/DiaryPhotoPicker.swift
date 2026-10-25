import PhotosUI
import SwiftUI
import ImageIO

struct DiaryPhotoPicker: UIViewControllerRepresentable {
    let limit: Int
    let selected: ([PHPickerResult]) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images; config.selectionLimit = max(1, limit)
        config.selection = .ordered
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ view: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(selected) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let selected: ([PHPickerResult]) -> Void
        init(_ selected: @escaping ([PHPickerResult]) -> Void) { self.selected = selected }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) { selected(results) }
    }
}

nonisolated enum DiaryPhotoImport {
    // Operates within the provider's temporary-file callback; no plaintext copy is retained by the app.
    static func normalize(url: URL) throws -> DiaryDocument.Photo {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? Int.max) <= 80 * 1_024 * 1_024,
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { throw CocoaError(.fileReadTooLarge) }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 1
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 1
        let longest = max(width, height), shortest = max(1, min(width, height))
        let maximum: Double = longest / shortest >= 3
            ? min(8192, longest * min(1, sqrt(12_000_000 / max(1, width * height)))) : 2048
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maximum),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.82)
        else { throw CocoaError(.fileReadCorruptFile) }
        return .init(jpeg: jpeg, width: image.width, height: image.height)
    }
}
