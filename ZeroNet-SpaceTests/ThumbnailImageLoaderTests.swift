import Testing
import UIKit

@testable import ZeroNet_Space

struct ThumbnailImageLoaderTests {

    @Test
    func downsampledImageDoesNotExceedRequestedPixelSize() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1_200, height: 800))
        let sourceImage = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 800))
        }
        let data = try #require(sourceImage.jpegData(compressionQuality: 0.9))

        let image = try #require(
            ThumbnailImageLoader.decode(data: data, maxPixelSize: 120)
        )
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale

        #expect(max(pixelWidth, pixelHeight) <= 120)
        #expect(pixelWidth > 0)
        #expect(pixelHeight > 0)
    }
}
