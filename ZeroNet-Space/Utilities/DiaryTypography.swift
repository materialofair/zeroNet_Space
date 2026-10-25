import UIKit

extension NSAttributedString.Key {
    static let diaryParagraph = NSAttributedString.Key("SealedPocket.Diary.Paragraph")
    static let diaryBold = NSAttributedString.Key("SealedPocket.Diary.Bold")
    static let diaryItalic = NSAttributedString.Key("SealedPocket.Diary.Italic")
}

/// Semantic attributes are persisted separately from fonts. Both the editor and PDF use these styles.
nonisolated enum DiaryTypography {
    static func kind(_ attributes: [NSAttributedString.Key: Any]) -> DiaryDocument.Paragraph {
        (attributes[.diaryParagraph] as? String).flatMap(DiaryDocument.Paragraph.init(rawValue:)) ?? .body
    }
    static func font(kind: DiaryDocument.Paragraph, bold: Bool, italic: Bool, scale: CGFloat = 1) -> UIFont {
        let size: CGFloat = kind == .heading ? 22 : 17
        let base = UIFont.systemFont(ofSize: size * scale, weight: kind == .heading ? .semibold : .regular)
        var traits = base.fontDescriptor.symbolicTraits
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        return UIFont(descriptor: base.fontDescriptor.withSymbolicTraits(traits) ?? base.fontDescriptor, size: 0)
    }
    static func attributes(_ run: DiaryDocument.Run = .init(), scale: CGFloat = 1, pdf: Bool = false) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5 * scale
        paragraph.paragraphSpacing = 10 * scale
        if run.paragraph == .heading { paragraph.paragraphSpacingBefore = 8 * scale; paragraph.paragraphSpacing = 10 * scale }
        if run.paragraph.isList { paragraph.firstLineHeadIndent = 30 * scale; paragraph.headIndent = 30 * scale }
        if run.paragraph == .quote { paragraph.firstLineHeadIndent = 18 * scale; paragraph.headIndent = 18 * scale }
        return [.font: font(kind: run.paragraph, bold: run.bold, italic: run.italic, scale: scale),
                .foregroundColor: pdf ? UIColor.black : UIColor.label,
                .paragraphStyle: paragraph, .diaryParagraph: run.paragraph.rawValue,
                .diaryBold: run.bold, .diaryItalic: run.italic,
                .underlineStyle: run.underline ? NSUnderlineStyle.single.rawValue : 0]
    }
    static func run(_ attributes: [NSAttributedString.Key: Any], text: String = "") -> DiaryDocument.Run {
        let font = attributes[.font] as? UIFont
        return .init(text: text,
            bold: attributes[.diaryBold] as? Bool ?? (font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true),
            italic: attributes[.diaryItalic] as? Bool ?? (font?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true),
            underline: (attributes[.underlineStyle] as? Int ?? 0) != 0, paragraph: kind(attributes))
    }
    static func number(in text: NSAttributedString, at index: Int) -> Int {
        let string = text.string as NSString
        var point = string.paragraphRange(for: NSRange(location: min(index, string.length), length: 0)).location
        var count = 1
        while point > 0 {
            let previous = string.paragraphRange(for: NSRange(location: point - 1, length: 0))
            guard kind(text.attributes(at: previous.location, effectiveRange: nil)) == .numbered else { break }
            count += 1; point = previous.location
        }
        return count
    }
}

/// Markers are drawn from paragraph semantics, never inserted into the user's text.
/// They therefore cannot be split from their paragraph by selection, undo or image movement.
final class DiaryLayoutManager: NSLayoutManager {
    var typingAttributes: (() -> [NSAttributedString.Key: Any])?
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage else { return }
        enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, used, _, glyphRange, _ in
            let index = self.characterIndexForGlyph(at: glyphRange.location)
            guard index < storage.length else { return }
            let attrs = storage.attributes(at: index, effectiveRange: nil)
            let kind = DiaryTypography.kind(attrs)
            guard kind.isList || kind == .quote else { return }
            let paragraph = (storage.string as NSString).paragraphRange(for: NSRange(location: index, length: 0))
            let font = attrs[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
            let scale = font.pointSize / 17
            if kind == .quote {
                UIColor.secondaryLabel.setFill()
                UIBezierPath(rect: CGRect(x: origin.x + rect.minX + 3 * scale, y: origin.y + rect.minY,
                                          width: 2 * scale, height: rect.height)).fill()
            } else if paragraph.location == index {
                let marker = kind == .bullet ? "•" : String(DiaryTypography.number(in: storage, at: index)) + "."
                let label = NSAttributedString(string: marker, attributes: [.font: font, .foregroundColor: UIColor.label])
                let size = label.size()
                label.draw(at: CGPoint(x: origin.x + rect.minX + 24 * scale - size.width,
                                       y: origin.y + used.minY))
            }
        }
        if storage.length == 0 || storage.string.hasSuffix("\n"), extraLineFragmentRect.height > 0 {
            let attrs = typingAttributes?() ?? [:], kind = DiaryTypography.kind(typingAttributes?() ?? [:])
            let font = attrs[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
            let scale = font.pointSize / 17, rect = extraLineFragmentRect
            if kind.isList {
                let marker = kind == .bullet ? "•" : String(storage.length > 0 ? DiaryTypography.number(in: storage, at: storage.length) : 1) + "."
                let text = NSAttributedString(string: marker, attributes: [.font: font, .foregroundColor: UIColor.label])
                text.draw(at: CGPoint(x: origin.x + rect.minX + 24 * scale - text.size().width, y: origin.y + rect.minY))
            } else if kind == .quote {
                UIColor.secondaryLabel.setFill()
                UIBezierPath(rect: CGRect(x: origin.x + rect.minX + 3 * scale, y: origin.y + rect.minY, width: 2 * scale, height: rect.height)).fill()
            }
        }

    }
}
