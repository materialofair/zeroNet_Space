import UIKit
import CoreText
import ImageIO

nonisolated final class DiaryPDFCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}

/// Produces an in-memory PDF of one snapshot. Never writes plaintext to the app's filesystem.
nonisolated enum DiaryPDFRenderer {
    enum RenderError: Error { case invalidImage, layoutFailed, tooLarge }
    static let pageSize = CGSize(width: 595.28, height: 841.89)
    static let margin: CGFloat = 42

    static func render(_ document: DiaryDocument, date: String,
                       cancellation: DiaryPDFCancellation = .init()) throws -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextCreator as String: "SealedPocket"]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        var failure: Error?
        let data = renderer.pdfData { context in
            let layout = Layout(context: context, cancellation: cancellation)
            do {
                try layout.newPage()
                if !document.title.isEmpty { try layout.text(NSAttributedString(string: document.title, attributes: attributes(size: 23, bold: true))) }
                try layout.text(NSAttributedString(string: date + "\n", attributes: attributes(size: 11)))
                let pending = NSMutableAttributedString(string: "")
                for run in document.runs {
                    try layout.check()
                    if let photo = run.photo {
                        if pending.length > 0 { try layout.richText(pending); pending.setAttributedString(NSAttributedString(string: "")) }
                        try autoreleasepool { try layout.photo(photo) }
                    } else {
                        pending.append(NSAttributedString(string: run.text, attributes: DiaryTypography.attributes(run, scale: 14.0 / 17, pdf: true)))
                    }
                }
                if pending.length > 0 { try layout.richText(pending) }
                try layout.check()
            } catch { failure = error }
        }
        if let failure { throw failure }
        guard !cancellation.isCancelled else { throw CancellationError() }
        guard data.count <= 100 * 1_024 * 1_024 else { throw RenderError.tooLarge }
        return data
    }

    private static func attributes(size: CGFloat, bold: Bool = false) -> [NSAttributedString.Key: Any] {
        let base = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let font = bold ? CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitBold, .traitBold) ?? base : base
        var spacing: CGFloat = 4
        let paragraph: CTParagraphStyle = withUnsafePointer(to: &spacing) { pointer in
            var setting = CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: pointer)
            return CTParagraphStyleCreate(&setting, 1)
        }
        return [NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
                NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph]
    }

    private final class Layout {
        let context: UIGraphicsPDFRendererContext
        let cancellation: DiaryPDFCancellation
        let width = pageSize.width - 2 * margin
        let bottom = pageSize.height - margin - 18
        var y = margin
        var page = 0
        var listNumber = 0
        var previousKind: DiaryDocument.Paragraph = .body
        init(context: UIGraphicsPDFRendererContext, cancellation: DiaryPDFCancellation) {
            self.context = context; self.cancellation = cancellation
        }
        func check() throws { if cancellation.isCancelled { throw CancellationError() } }
        func newPage() throws {
            try check(); guard page < 1_000 else { throw RenderError.tooLarge }
            context.beginPage(); page += 1; y = margin
            let label = NSAttributedString(string: String(page), attributes: attributes(size: 9))
            let line = CTLineCreateWithAttributedString(label)
            let cg = context.cgContext
            cg.saveGState(); cg.translateBy(x: pageSize.width / 2, y: pageSize.height - 24)
            cg.scaleBy(x: 1, y: -1); cg.textPosition = .zero; CTLineDraw(line, cg); cg.restoreGState()
        }
        func richText(_ value: NSAttributedString) throws {
            let string = value.string as NSString
            var offset = 0
            while offset < string.length {
                try check()
                let range = string.paragraphRange(for: NSRange(location: offset, length: 0))
                let paragraph = value.attributedSubstring(from: range)
                let kind = DiaryTypography.kind(paragraph.attributes(at: 0, effectiveRange: nil))
                if kind == .numbered { listNumber = previousKind == .numbered ? listNumber + 1 : 1 }
                else { listNumber = 0 }
                if kind == .heading {
                    let setter = CTFramesetterCreateWithAttributedString(paragraph)
                    let size = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: 0), nil,
                        CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), nil)
                    let required = min(bottom - margin, ceil(size.height) + 52)
                    if bottom - y < required { try newPage() }
                }
                try text(paragraph, kind: kind, number: listNumber)
                previousKind = kind; offset = NSMaxRange(range)
            }
        }
        func text(_ value: NSAttributedString, kind: DiaryDocument.Paragraph = .body, number: Int = 0) throws {
            let setter = CTFramesetterCreateWithAttributedString(value)
            var offset = 0
            while offset < value.length {
                try check()
                if bottom - y < 32 { try newPage() }
                let available = bottom - y
                let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: available), transform: nil)
                let frame = CTFramesetterCreateFrame(setter, CFRange(location: offset, length: 0), path, nil)
                let visible = CTFrameGetVisibleStringRange(frame)
                guard visible.length > 0 else { throw RenderError.layoutFailed }
                let cg = context.cgContext
                cg.saveGState(); cg.translateBy(x: margin, y: y + available); cg.scaleBy(x: 1, y: -1)
                CTFrameDraw(frame, cg)
                let lines = CTFrameGetLines(frame) as! [CTLine]
                var origins = [CGPoint](repeating: .zero, count: lines.count)
                CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
                if kind.isList, offset == 0, let origin = origins.first {
                    let marker = NSAttributedString(string: kind == .bullet ? "•" : String(number) + ".",
                        attributes: DiaryTypography.attributes(scale: 14.0 / 17, pdf: true))
                    let line = CTLineCreateWithAttributedString(marker)
                    let length = CTLineGetTypographicBounds(line, nil, nil, nil)
                    cg.textPosition = CGPoint(x: 24 * 14.0 / 17 - length, y: origin.y)
                    CTLineDraw(line, cg)
                }
                if kind == .quote {
                    cg.setStrokeColor(CGColor(gray: 0.45, alpha: 1)); cg.setLineWidth(1.5)
                    for (line, origin) in zip(lines, origins) {
                        var ascent: CGFloat = 0, descent: CGFloat = 0
                        CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                        cg.move(to: CGPoint(x: 3, y: origin.y - descent - 2))
                        cg.addLine(to: CGPoint(x: 3, y: origin.y + ascent + 2)); cg.strokePath()
                    }
                }
                cg.restoreGState()
                if let last = lines.last, let origin = origins.last {
                    var descent: CGFloat = 0
                    CTLineGetTypographicBounds(last, nil, &descent, nil)
                    y += min(available, ceil(available - origin.y + descent) + 8)
                }
                offset += visible.length
                if offset < value.length { try newPage() }
            }
        }
        func photo(_ photo: DiaryDocument.Photo) throws {
            previousKind = .body; listNumber = 0
            try check()
            guard let source = CGImageSourceCreateWithData(photo.jpeg as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary),
                  image.width > 0, image.height > 0 else { throw RenderError.invalidImage }
            let height = width * CGFloat(image.height) / CGFloat(image.width)
            let pageHeight = bottom - margin
            if height > pageHeight {
                // Never cut a long image's embedded writing at arbitrary page boundaries.
                // Embed the complete source on its own page; readers can zoom the PDF.
                // A short preceding paragraph stays with its image rather than
                // becoming an almost-empty page. Longer text gets a dedicated image page.
                if y > margin + 80 { try newPage() }
                let fittedHeight = bottom - y - 56
                let fittedWidth = fittedHeight * CGFloat(image.width) / CGFloat(image.height)
                UIImage(cgImage: image).draw(in: CGRect(x: margin + (width - fittedWidth) / 2,
                    y: y, width: fittedWidth, height: fittedHeight))
                y += fittedHeight + 8
                try text(NSAttributedString(string: String(localized: "diary.pdf.longImage"), attributes: attributes(size: 10)))
                y = bottom
            } else {
                if height > bottom - y { try newPage() }
                UIImage(cgImage: image).draw(in: CGRect(x: margin, y: y, width: width, height: height))
                y += height + 12
            }

        }
    }
}
