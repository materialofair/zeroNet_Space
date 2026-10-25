import SwiftUI
import UIKit

final class DiaryAttachment: NSTextAttachment {
    let photo: DiaryDocument.Photo
    init(photo: DiaryDocument.Photo) {
        self.photo = photo
        super.init(data: nil, ofType: nil)
        // Draw a proportional, bounded preview. The full normalized image stays in the document.
        image = autoreleasepool {
            guard let original = UIImage(data: photo.jpeg) else { return nil }
            let width: CGFloat = 760
            let fullHeight = width * CGFloat(photo.height) / CGFloat(max(1, photo.width))
            let height = photo.height >= photo.width * 3 ? min(420, fullHeight) : fullHeight
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { _ in
                original.draw(in: CGRect(x: 0, y: 0, width: width,
                    height: width * CGFloat(photo.height) / CGFloat(max(1, photo.width))))
            }
        }
    }
    required init?(coder: NSCoder) { nil }
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let width = max(1, min(760, lineFrag.width - 2 * (textContainer?.lineFragmentPadding ?? 0)))
        let ratio = (image?.size.height ?? 1) / max(1, image?.size.width ?? 1)
        return CGRect(x: 0, y: -4, width: width, height: width * ratio)
    }
}

final class DiaryNativeTextView: UITextView {
    var headingHost: UIHostingController<AnyView>?
    var backspaceAtStart: (() -> Bool)?
    var prepareComposition: (() -> Void)?
    var finishComposition: (() -> Void)?
    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        prepareComposition?()
        super.setMarkedText(markedText, selectedRange: selectedRange)
    }
    override func unmarkText() {
        super.unmarkText()
        finishComposition?()
    }
    override func deleteBackward() {
        if selectedRange == NSRange(location: 0, length: 0), markedTextRange == nil,
           backspaceAtStart?() == true { return }
        super.deleteBackward()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let host = headingHost, bounds.width > 0 else { return }
        let height = ceil(host.sizeThatFits(in: CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)).height)
        host.view.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height)
        if abs(textContainerInset.top - height - 16) > 0.5 {
            var inset = textContainerInset; inset.top = height + 16; textContainerInset = inset
        }
    }

    // Photos enter only through the ordered, bounded import pipeline. UIKit's
    // implicit rich paste would otherwise create attachments with no saved asset.
    override func paste(_ sender: Any?) {
        if let string = UIPasteboard.general.string { insertText(string) }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if ["share:", "_share:", "_translate:", "_define:", "_promptForReplace:"].contains(NSStringFromSelector(action)) { return false }
        if action == #selector(paste(_:)) { return UIPasteboard.general.hasStrings }
        if action == #selector(copy(_:)) || action == #selector(cut(_:)) {
            var includesPhoto = false
            if NSMaxRange(selectedRange) <= textStorage.length {
                textStorage.enumerateAttribute(.attachment, in: selectedRange) { value, _, _ in
                    if value != nil { includesPhoto = true }
                }
            }
            if includesPhoto { return false }
        }
        return super.canPerformAction(action, withSender: sender)
    }
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        builder.remove(menu: .share)
        builder.remove(menu: .lookup)
    }
}

@MainActor final class DiaryTextController: ObservableObject {
    weak var view: UITextView?
    var changed: (() -> Void)?
    var locked = false
    private var typingRun = DiaryDocument.Run()
    private var typingLocation: Int?
    private var pendingInput: (range: NSRange, oldLength: Int, style: DiaryDocument.Run)?
    private var composingRange: NSRange?
    private var mutating = false
    enum State: Equatable { case off, on, mixed }
    enum Inline: String, CaseIterable { case bold, italic, underline }
    @Published private(set) var inlineState: [Inline: State] = [:]
    @Published private(set) var paragraphState: DiaryDocument.Paragraph? = .body
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    var scale: CGFloat { UIFontMetrics(forTextStyle: .body).scaledValue(for: 17) / 17 }
    var selection: NSRange { view?.selectedRange ?? NSRange(location: 0, length: 0) }
    var font: UIFont { UIFont.preferredFont(forTextStyle: .body) }
    var attributes: [NSAttributedString.Key: Any] { DiaryTypography.attributes(scale: scale) }

    func attributed(_ document: DiaryDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in document.runs {
            if let photo = run.photo {
                let item = NSMutableAttributedString(attachment: DiaryAttachment(photo: photo))
                item.addAttributes(attributes, range: NSRange(location: 0, length: item.length))
                result.append(item)
            } else {
                result.append(NSAttributedString(string: run.text, attributes: DiaryTypography.attributes(run, scale: scale)))
            }
        }
        return result
    }

    func runs() -> [DiaryDocument.Run] {
        guard let text = view?.attributedText, text.length > 0 else { return [] }
        var runs: [DiaryDocument.Run] = []
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attrs, range, _ in
            if let attachment = attrs[.attachment] as? DiaryAttachment {
                runs.append(.init(photo: attachment.photo))
            } else {
                let run = DiaryTypography.run(attrs, text: (text.string as NSString).substring(with: range))
                if let last = runs.indices.last, runs[last].photo == nil,
                   runs[last].bold == run.bold, runs[last].italic == run.italic,
                   runs[last].underline == run.underline, runs[last].paragraph == run.paragraph {
                    runs[last].text += run.text
                } else { runs.append(run) }
            }
        }
        return runs
    }

    func refreshSelection() {
        guard let view, !locked else { return }
        var styles: [DiaryDocument.Run] = []
        if view.selectedRange.length > 0, NSMaxRange(view.selectedRange) <= view.textStorage.length {
            view.textStorage.enumerateAttributes(in: view.selectedRange) { attrs, _, _ in
                if attrs[.attachment] == nil { styles.append(DiaryTypography.run(attrs)) }
            }
        }
        if styles.isEmpty { styles = [view.isFirstResponder ? typingRun : DiaryTypography.run(view.typingAttributes)] }
        func state(_ values: [Bool]) -> State { values.allSatisfy { $0 } ? .on : values.allSatisfy { !$0 } ? .off : .mixed }
        let inline: [Inline: State] = [.bold: state(styles.map(\.bold)), .italic: state(styles.map(\.italic)), .underline: state(styles.map(\.underline))]
        let paragraph = styles.allSatisfy { $0.paragraph == styles.first?.paragraph } ? styles.first?.paragraph : nil
        if inlineState != inline { inlineState = inline }
        if paragraphState != paragraph { paragraphState = paragraph }
        if canUndo != (view.undoManager?.canUndo == true) { canUndo = view.undoManager?.canUndo == true }
        if canRedo != (view.undoManager?.canRedo == true) { canRedo = view.undoManager?.canRedo == true }
    }

    func refreshFonts() {
        guard let view, !locked, view.markedTextRange == nil else { return }
        let selection = view.selectedRange, offset = view.contentOffset
        view.textStorage.beginEditing()
        view.textStorage.enumerateAttributes(in: NSRange(location: 0, length: view.textStorage.length)) { attrs, range, _ in
            guard attrs[.attachment] == nil else { return }
            view.textStorage.addAttributes(DiaryTypography.attributes(DiaryTypography.run(attrs), scale: scale), range: range)
        }
        view.textStorage.endEditing()
        view.typingAttributes = DiaryTypography.attributes(DiaryTypography.run(view.typingAttributes), scale: scale)
        view.selectedRange = selection; view.setContentOffset(offset, animated: false)
    }

    func replace(_ range: NSRange, with replacement: NSAttributedString) {
        guard !locked, let view, NSMaxRange(range) <= view.textStorage.length else { return }
        edit(range, replacement: replacement,
             selection: NSRange(location: range.location + replacement.length, length: 0), typingAfter: attributes)
    }

    func insert(_ photos: [DiaryDocument.Photo], at range: NSRange) {
        guard let view, !locked else { return }
        let text = view.textStorage.string as NSString
        let location = min(range.location, text.length)
        let insertion = NSMutableAttributedString()
        if location > 0 && text.substring(with: NSRange(location: location - 1, length: 1)) != "\n" {
            insertion.append(NSAttributedString(string: "\n", attributes: attributes))
        }
        for photo in photos {
            let item = NSMutableAttributedString(attachment: DiaryAttachment(photo: photo))
            item.addAttributes(attributes, range: NSRange(location: 0, length: item.length))
            insertion.append(item)
            insertion.append(NSAttributedString(string: "\n", attributes: attributes))
        }
        replace(NSRange(location: location, length: min(range.length, text.length - location)), with: insertion)
    }

    func write(above: Bool, imageRange: NSRange) {
        guard !locked, let view else { return }
        var point = above ? imageRange.location : NSMaxRange(imageRange)
        let text = view.textStorage.string as NSString
        if !above || (point > 0 && text.substring(with: NSRange(location: point - 1, length: 1)) != "\n") {
            replace(NSRange(location: point, length: 0), with: NSAttributedString(string: "\n", attributes: attributes))
            if !above { point += 1 }
        }
        view.selectedRange = NSRange(location: point, length: 0)
        view.becomeFirstResponder()
        view.scrollRangeToVisible(view.selectedRange)
    }

    func move(photoID: UUID, to target: Int) {
        guard !locked, let view else { return }
        var found: NSRange?
        view.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: view.textStorage.length)) { value, range, stop in
            if (value as? DiaryAttachment)?.photo.id == photoID { found = range; stop.pointee = true }
        }
        guard let source = found,
              target < source.location || target > NSMaxRange(source) else { return }
        let old = NSAttributedString(attributedString: view.textStorage)
        let moved = NSMutableAttributedString(attributedString: old)
        let photo = moved.attributedSubstring(from: source)
        moved.deleteCharacters(in: source)
        let destination = min(moved.length, max(0, target - (target > source.location ? source.length : 0)))
        let insertion = NSMutableAttributedString(string: "\n", attributes: attributes)
        insertion.append(photo); insertion.append(NSAttributedString(string: "\n", attributes: attributes))
        moved.insert(insertion, at: destination)
        replace(NSRange(location: 0, length: old.length), with: moved)
        view.selectedRange = NSRange(location: destination + insertion.length, length: 0)
    }

    private func applyTyping(_ attributes: [NSAttributedString.Key: Any]) {
        guard let view else { return }
        typingRun = DiaryTypography.run(attributes); typingLocation = view.selectedRange.location
        view.typingAttributes = attributes
        let selection = view.selectedRange
        // UIKit finishes its Return/selection bookkeeping after shouldChange returns.
        // Reapply only to that unchanged cursor, never to marked input or a moved selection.
        DispatchQueue.main.async { [weak self, weak view] in
            guard let self, !self.locked, let view, view.selectedRange == selection,
                  view.markedTextRange == nil else { return }
            view.typingAttributes = attributes; view.setNeedsDisplay(); self.refreshSelection()
        }
    }

    func focusBody() {
        guard let view, !locked else { return }
        if !view.isFirstResponder { view.endEditing(true); view.becomeFirstResponder() }
        view.scrollRangeToVisible(view.selectedRange)
    }
    func hideKeyboard() { view?.endEditing(true); view?.resignFirstResponder() }

    func toggleBold() { toggle(.bold) }
    func toggle(_ inline: Inline) {
        guard !locked, let view, view.markedTextRange == nil else { return }
        focusBody(); refreshSelection()
        let enabled = inlineState[inline] != .on
        func updated(_ attrs: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
            var run = DiaryTypography.run(attrs)
            switch inline { case .bold: run.bold = enabled; case .italic: run.italic = enabled; case .underline: run.underline = enabled }
            return DiaryTypography.attributes(run, scale: scale)
        }
        let range = view.selectedRange
        if range.length == 0 {
            applyTyping(updated(DiaryTypography.attributes(typingRun, scale: scale)))
            refreshSelection(); return
        }
        let replacement = NSMutableAttributedString(attributedString: view.textStorage.attributedSubstring(from: range))
        replacement.enumerateAttributes(in: NSRange(location: 0, length: replacement.length)) { attrs, local, _ in
            guard attrs[.attachment] == nil else { return }
            replacement.addAttributes(updated(attrs), range: local)
        }
        edit(range, replacement: replacement, selection: range)
    }

    func setParagraph(_ kind: DiaryDocument.Paragraph) {
        guard !locked, let view, view.markedTextRange == nil else { return }
        focusBody()
        let string = view.textStorage.string as NSString, selection = view.selectedRange
        guard string.length > 0, !(selection.location == string.length && string.hasSuffix("\n")) else {
            var run = typingRun; run.paragraph = kind
            applyTyping(DiaryTypography.attributes(run, scale: scale)); view.setNeedsDisplay(); refreshSelection(); return
        }
        // An end at the next paragraph's beginning does not select that paragraph.
        let span = NSRange(location: selection.location, length: max(0, selection.length - 1))
        let range = string.paragraphRange(for: span)
        let replacement = NSMutableAttributedString(attributedString: view.textStorage.attributedSubstring(from: range))
        let paragraphs = replacement.string as NSString
        let caret = min(max(0, selection.location - range.location), max(0, replacement.length - 1))
        var typingKind = kind
        var offset = 0
        while offset < replacement.length {
            let paragraph = paragraphs.paragraphRange(for: NSRange(location: offset, length: 0))
            var hasPhoto = false
            replacement.enumerateAttribute(.attachment, in: paragraph) { value, _, stop in
                if value != nil { hasPhoto = true; stop.pointee = true }
            }
            if !hasPhoto {
                replacement.enumerateAttributes(in: paragraph) { attrs, local, _ in
                    var run = DiaryTypography.run(attrs); run.paragraph = kind
                    replacement.addAttributes(DiaryTypography.attributes(run, scale: scale), range: local)
                }
            } else if NSLocationInRange(caret, paragraph) {
                // A skipped image paragraph must also keep its actual future-input style.
                typingKind = DiaryTypography.kind(replacement.attributes(at: caret, effectiveRange: nil))
            }
            offset = NSMaxRange(paragraph)
        }
        var typing = typingRun; typing.paragraph = typingKind
        edit(range, replacement: replacement, selection: selection,
             typingAfter: DiaryTypography.attributes(typing, scale: scale))
    }

    private func edit(_ range: NSRange, replacement: NSAttributedString, selection: NSRange,
                      typingAfter: [NSAttributedString.Key: Any]? = nil) {
        guard let view else { return }
        let old = view.textStorage.attributedSubstring(from: range), oldSelection = view.selectedRange
        let offset = view.contentOffset, typing = view.typingAttributes
        view.undoManager?.registerUndo(withTarget: self) { controller in
            controller.edit(NSRange(location: range.location, length: replacement.length), replacement: old, selection: oldSelection, typingAfter: typing)
        }
        mutating = true
        view.textStorage.replaceCharacters(in: range, with: replacement)
        view.selectedRange = selection
        applyTyping(typingAfter ?? typing)
        mutating = false
        view.setNeedsDisplay()
        view.setContentOffset(offset, animated: false)
        changed?(); refreshSelection()
    }

    /// Structural Return/Backspace, without literal bullet characters in the document.
    func shouldChange(_ range: NSRange, replacement: String) -> Bool {
        guard !locked, let view else { return false }
        if view.markedTextRange != nil {
            if pendingInput == nil { pendingInput = (range, view.textStorage.length, typingRun) }
            return true
        }
        let string = view.textStorage.string as NSString
        guard range.location <= string.length else { return false }
        let cursor = replacement.isEmpty && range.length == 1 ? NSMaxRange(range) : range.location
        let paragraph = string.paragraphRange(for: NSRange(location: cursor, length: 0))
        let styleIndex = cursor < string.length ? cursor : (cursor > 0 && !string.hasSuffix("\n") ? cursor - 1 : nil)
        let kind = styleIndex.map { DiaryTypography.kind(view.textStorage.attributes(at: $0, effectiveRange: nil)) } ?? typingRun.paragraph
        if replacement == "\n", range.length == 0, kind != .body {
            let empty = string.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if empty && (kind.isList || kind == .quote) { setParagraph(.body); return false }
            // A heading's semibold font is structural, not a request for bold body typing.
            var next: DiaryDocument.Run = kind == .heading ? .init() : typingRun
            next.paragraph = kind == .heading ? .body : kind
            let attrs = DiaryTypography.attributes(next, scale: scale)
            replaceBoundary(range, text: "\n", following: kind == .heading ? .body : nil, typingAfter: attrs)
            return false
        }
        if replacement.isEmpty, range.length <= 1, NSMaxRange(range) == paragraph.location,
           kind != .body {
            setParagraph(.body); return false
        }
        let removed = string.substring(with: range)
        if replacement.rangeOfCharacter(from: .newlines) != nil || removed.rangeOfCharacter(from: .newlines) != nil {
            replaceBoundary(range, text: replacement, typingAfter: DiaryTypography.attributes(typingRun, scale: scale))
            return false
        }
        pendingInput = (range, view.textStorage.length, typingRun)
        return true
    }

    /// Paragraph joins adopt the first paragraph's kind. Splits retain that kind,
    /// except Return in a heading explicitly starts body text. One undo restores both
    /// text and paragraph semantics; normalization never runs during marked input.
    private func replaceBoundary(_ range: NSRange, text: String, following: DiaryDocument.Paragraph? = nil,
                                 typingAfter: [NSAttributedString.Key: Any]) {
        guard let view else { return }
        let string = view.textStorage.string as NSString
        // Include the first surviving character after a removed newline so the
        // joined paragraph, not only the deleted paragraph, is normalized.
        let extent = NSRange(location: range.location, length: min(string.length - range.location, range.length + 1))
        let region = string.paragraphRange(for: extent)
        let fragment = NSMutableAttributedString(attributedString: view.textStorage.attributedSubstring(from: region))
        let local = NSRange(location: range.location - region.location, length: range.length)
        let beforeKind: DiaryDocument.Paragraph = region.length > 0 ? DiaryTypography.kind(fragment.attributes(at: 0, effectiveRange: nil)) : typingRun.paragraph
        var insertionStyle = typingRun; insertionStyle.paragraph = beforeKind
        fragment.replaceCharacters(in: local, with: NSAttributedString(string: text, attributes: DiaryTypography.attributes(insertionStyle, scale: scale)))
        let cursor = local.location + (text as NSString).length, value = fragment.string as NSString
        var offset = 0
        while offset < fragment.length {
            let paragraph = value.paragraphRange(for: NSRange(location: offset, length: 0))
            var kind = DiaryTypography.kind(fragment.attributes(at: offset, effectiveRange: nil))
            if let following, NSLocationInRange(cursor, paragraph) { kind = following }
            fragment.enumerateAttributes(in: paragraph) { attrs, part, _ in
                guard attrs[.attachment] == nil else { return }
                var run = DiaryTypography.run(attrs); run.paragraph = kind
                fragment.addAttributes(DiaryTypography.attributes(run, scale: scale), range: part)
            }
            offset = NSMaxRange(paragraph)
        }
        var next = DiaryTypography.run(typingAfter)
        if cursor < fragment.length {
            next.paragraph = DiaryTypography.kind(fragment.attributes(at: cursor, effectiveRange: nil))
        } else if cursor > 0, !value.hasSuffix("\n") {
            next.paragraph = DiaryTypography.kind(fragment.attributes(at: cursor - 1, effectiveRange: nil))
        }
        edit(region, replacement: fragment, selection: NSRange(location: region.location + cursor, length: 0),
             typingAfter: DiaryTypography.attributes(next, scale: scale))
    }

    func selectionChanged() {
        guard let view, !locked, !mutating, pendingInput == nil, view.markedTextRange == nil else { return }
        let selection = view.selectedRange
        if selection.length == 0, typingLocation != selection.location {
            if view.textStorage.length > 0 {
                let string = view.textStorage.string as NSString
                var index = min(selection.location, string.length - 1)
                if selection.location > 0, string.substring(with: NSRange(location: selection.location - 1, length: 1)) != "\n" { index = selection.location - 1 }
                typingRun = DiaryTypography.run(view.textStorage.attributes(at: index, effectiveRange: nil))
                view.typingAttributes = DiaryTypography.attributes(typingRun, scale: scale)
            }
            typingLocation = selection.location
        }
        refreshSelection()
    }

    func beginComposition() {
        guard let view, !locked, pendingInput == nil else { return }
        pendingInput = (view.selectedRange, view.textStorage.length, typingRun)
    }

    func textChanged() {
        guard let view, !locked else { return }
        if let marked = view.markedTextRange {
            composingRange = NSRange(location: view.offset(from: view.beginningOfDocument, to: marked.start),
                length: view.offset(from: marked.start, to: marked.end))
            return
        }
        if let input = pendingInput {
            let count = max(0, view.textStorage.length - input.oldLength + input.range.length)
            var range = NSRange(location: min(input.range.location, view.textStorage.length), length: count)
            if let composingRange { range = NSUnionRange(range, composingRange) }
            range.length = min(range.length, view.textStorage.length - range.location)
            if range.length > 0 {
                // UITextView strips custom typing keys. Restore semantic attributes only
                // on the committed insertion, without resetting text, selection or IME state.
                mutating = true
                view.textStorage.addAttributes(DiaryTypography.attributes(input.style, scale: scale), range: range)
                mutating = false
            }
            typingRun = input.style
        }
        pendingInput = nil; composingRange = nil; typingLocation = view.selectedRange.location
        applyTyping(DiaryTypography.attributes(typingRun, scale: scale)); refreshSelection()
    }

    func clear() {
        locked = true
        view?.resignFirstResponder()
        view?.undoManager?.removeAllActions()
        view?.accessibilityCustomActions = nil
        view?.attributedText = NSAttributedString(string: "")
        (view as? DiaryNativeTextView)?.headingHost?.rootView = AnyView(EmptyView())
        changed = nil
    }
}

struct DiaryTextView: UIViewRepresentable {
    let controller: DiaryTextController
    let document: DiaryDocument
    let editing: Bool
    let heading: AnyView
    let onChange: () -> Void
    let onPhoto: (NSRange, DiaryDocument.Photo) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    func makeUIView(context: Context) -> DiaryNativeTextView {
        let storage = NSTextStorage()
        let layout = DiaryLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        let view = DiaryNativeTextView(frame: .zero, textContainer: container)
        let host = UIHostingController(rootView: AnyView(heading.environment(\.dynamicTypeSize, typeSize)))
        host.view.backgroundColor = .clear
        view.addSubview(host.view); view.headingHost = host
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 48, right: 16)
        view.adjustsFontForContentSizeCategory = true
        view.autocorrectionType = .no; view.spellCheckingType = .no
        view.smartQuotesType = .no
        view.inlinePredictionType = .no
        if #available(iOS 18.0, *) { view.writingToolsBehavior = .none }
        view.textDragInteraction?.isEnabled = false
        view.accessibilityIdentifier = "diary.body"
        view.attributedText = controller.attributed(document)
        view.typingAttributes = controller.attributes
        controller.view = view
        view.backspaceAtStart = { [weak controller] in
            controller?.shouldChange(NSRange(location: 0, length: 0), replacement: "") == false
        }
        layout.typingAttributes = { [weak view] in view?.typingAttributes ?? [:] }
        view.prepareComposition = { [weak controller] in controller?.beginComposition() }
        view.finishComposition = { [weak controller] in controller?.textChanged() }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapPhoto(_:)))
        tap.cancelsTouchesInView = false; tap.delegate = context.coordinator; view.addGestureRecognizer(tap)
        return view
    }
    func updateUIView(_ view: DiaryNativeTextView, context: Context) {
        view.headingHost?.rootView = AnyView(heading.environment(\.dynamicTypeSize, typeSize))
        view.setNeedsLayout()
        controller.changed = onChange
        let editable = editing && !controller.locked
        if view.isEditable != editable { view.isEditable = editable }
        if view.isSelectable != editable { view.isSelectable = editable }
        context.coordinator.parent = self
        // TextKit reflows its text container when the window changes width.
        // Do not invalidate the whole long document on every status/typing update.
        var actions: [UIAccessibilityCustomAction] = []
        if !controller.locked {
            view.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: view.textStorage.length)) { value, range, _ in
                if let attachment = value as? DiaryAttachment {
                    let name = String(localized: "diary.viewPhoto") + " " + String(actions.count + 1)
                    actions.append(UIAccessibilityCustomAction(name: name) { [weak controller] _ in
                        guard controller?.locked == false else { return false }
                        onPhoto(range, attachment.photo); return true
                    })
                }
            }
        }
        view.accessibilityCustomActions = actions
        if context.coordinator.typeSize != typeSize {
            context.coordinator.typeSize = typeSize
            controller.refreshFonts()
        }
        if !editing { view.resignFirstResponder() }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: DiaryTextView
        var typeSize: DynamicTypeSize?
        init(_ parent: DiaryTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.controller.textChanged(); parent.onChange() }
        func textViewDidChangeSelection(_ textView: UITextView) { parent.controller.selectionChanged() }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            parent.controller.shouldChange(range, replacement: text)
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
        @objc func tapPhoto(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? UITextView, !parent.controller.locked else { return }
            var point = gesture.location(in: view)
            point.x -= view.textContainerInset.left; point.y -= view.textContainerInset.top
            let glyph = view.layoutManager.glyphIndex(for: point, in: view.textContainer)
            guard glyph < view.layoutManager.numberOfGlyphs else { return }
            let rect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: view.textContainer)
            guard rect.contains(point) else { return }
            let index = view.layoutManager.characterIndexForGlyph(at: glyph)
            guard index < view.textStorage.length,
                  let photo = view.textStorage.attribute(.attachment, at: index, effectiveRange: nil) as? DiaryAttachment else { return }
            parent.onPhoto(NSRange(location: index, length: 1), photo.photo)
        }
    }
}
