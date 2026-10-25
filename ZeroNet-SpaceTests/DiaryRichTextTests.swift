import XCTest
import UIKit
import SwiftData
@testable import ZeroNet_Space

@MainActor final class DiaryRichTextTests: XCTestCase {
    @MainActor private final class InputDelegate: NSObject, UITextViewDelegate {
        let controller: DiaryTextController
        init(_ controller: DiaryTextController) { self.controller = controller }
        func textView(_ view: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool { controller.shouldChange(range, replacement: text) }
        func textViewDidChange(_ view: UITextView) { controller.textChanged() }
        func textViewDidChangeSelection(_ view: UITextView) { controller.selectionChanged() }
    }
    private func document(_ runs: [DiaryDocument.Run]) -> DiaryDocument {
        .init(id: UUID(), title: "虚构的两行标题\nA quiet afternoon 🌿", runs: runs, updatedAt: Date())
    }
    private func editor(_ runs: [DiaryDocument.Run]) -> (DiaryTextController, UITextView) {
        let controller = DiaryTextController(), view = UITextView()
        controller.view = view; view.attributedText = controller.attributed(document(runs))
        view.typingAttributes = controller.attributes
        return (controller, view)
    }
    func testOldVersionOneMissingFormattingFieldsDecodesWithoutChangingContent() throws {
        let original = document([.init(text: "原文 😀\n", bold: true)])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json["runs"] = [["text": "原文 😀\n", "bold": true]]
        let decoded = try JSONDecoder().decode(DiaryDocument.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.runs, original.runs); XCTAssertEqual(decoded.version, 1)
    }
    func testSemanticStylesAndPhotosRoundTripThroughNativeTextAndJSON() throws {
        let photo = DiaryDocument.Photo(jpeg: Data(), width: 10, height: 10)
        let runs: [DiaryDocument.Run] = [.init(text: "小标题\n", paragraph: .heading),
            .init(text: "中英 😀", bold: true, italic: true, underline: true), .init(text: "\n"),
            .init(text: "列表一\n列表二\n", paragraph: .numbered), .init(text: "引用\n", paragraph: .quote),
            .init(photo: photo), .init(text: "\n图片之间\n"), .init(photo: photo)]
        let (controller, view) = editor(runs)
        XCTAssertEqual(controller.runs(), runs)
        let data = try JSONEncoder().encode(document(controller.runs()))
        XCTAssertEqual(try JSONDecoder().decode(DiaryDocument.self, from: data).runs, runs)
        withExtendedLifetime(view) {}
    }
    func testSelectionTogglesOnlyRequestedAttributeAndKeepsRangeAndUndo() {
        let (controller, view) = editor([.init(text: "中文😀 bold", bold: true, underline: true)])
        let range = (view.textStorage.string as NSString).range(of: "中文😀")
        view.selectedRange = range; controller.toggle(.italic)
        XCTAssertEqual(view.selectedRange, range)
        let changed = controller.runs(); XCTAssertTrue(changed[0].bold); XCTAssertTrue(changed[0].italic); XCTAssertTrue(changed[0].underline)
        XCTAssertFalse(changed.last!.italic)
        controller.toggle(.bold)
        XCTAssertTrue(controller.runs()[0].italic); XCTAssertTrue(controller.runs()[0].underline); XCTAssertFalse(controller.runs()[0].bold)
        view.undoManager?.undo()
        XCTAssertEqual(controller.runs(), [.init(text: "中文😀 bold", bold: true, underline: true)])
    }
    func testMixedSelectionAndTypingStateDoNotClaimUniformFormatting() {
        let (controller, view) = editor([.init(text: "bold", bold: true), .init(text: " normal")])
        view.selectedRange = NSRange(location: 0, length: view.textStorage.length); controller.refreshSelection()
        XCTAssertEqual(controller.inlineState[.bold], .mixed)
        controller.toggle(.italic); XCTAssertTrue(controller.runs().allSatisfy(\.italic))
        XCTAssertEqual(controller.inlineState[.bold], .mixed)
        view.selectedRange = NSRange(location: view.textStorage.length, length: 0)
        view.typingAttributes = controller.attributes
        controller.toggle(.underline)
        XCTAssertEqual(controller.inlineState[.underline], .on)
        XCTAssertFalse(controller.runs().contains { $0.underline })
    }
    func testParagraphRangeAndInlineStylesStayIndependent() {
        let (controller, view) = editor([.init(text: "one ", bold: true), .init(text: "😀\ntwo\nthree")])
        view.selectedRange = NSRange(location: 2, length: 7)
        let selection = view.selectedRange
        controller.setParagraph(.quote)
        XCTAssertEqual(view.selectedRange, selection)
        let runs = controller.runs()
        XCTAssertTrue(runs[0].bold); XCTAssertEqual(runs[0].paragraph, .quote)
        XCTAssertEqual(runs.last?.paragraph, .body)
        XCTAssertEqual(view.textStorage.string, "one 😀\ntwo\nthree")
    }
    func testListsContinueExitOnEmptyReturnAndBackspaceKeepsText() {
        let (controller, view) = editor([.init(text: "第一项", paragraph: .bullet)])
        view.selectedRange = NSRange(location: view.textStorage.length, length: 0)
        view.typingAttributes = DiaryTypography.attributes(.init(paragraph: .bullet))
        XCTAssertFalse(controller.shouldChange(view.selectedRange, replacement: "\n"))
        XCTAssertEqual(view.textStorage.string, "第一项\n")
        XCTAssertEqual(DiaryTypography.kind(view.typingAttributes), .bullet)
        XCTAssertFalse(controller.shouldChange(view.selectedRange, replacement: "\n"))
        XCTAssertEqual(view.textStorage.string, "第一项\n")
        XCTAssertEqual(DiaryTypography.kind(view.typingAttributes), .body)
        view.attributedText = controller.attributed(document([.init(text: "前文\n"), .init(text: "保留", paragraph: .numbered)]))
        view.selectedRange = NSRange(location: 3, length: 0)
        XCTAssertFalse(controller.shouldChange(NSRange(location: 2, length: 1), replacement: ""))
        XCTAssertEqual(view.textStorage.string, "前文\n保留")
        XCTAssertEqual(controller.runs().last?.paragraph, .body)
    }
    func testHeadingReturnReturnsToBodyAndNumberingRestartsAfterOtherParagraph() {
        let (controller, view) = editor([.init(text: "Heading", paragraph: .heading)])
        view.selectedRange = NSRange(location: 7, length: 0)
        view.typingAttributes = DiaryTypography.attributes(.init(paragraph: .heading))
        XCTAssertFalse(controller.shouldChange(view.selectedRange, replacement: "\n"))
        XCTAssertEqual(DiaryTypography.kind(view.typingAttributes), .body)
        XCTAssertFalse(DiaryTypography.run(view.typingAttributes).bold)
        view.attributedText = controller.attributed(document([.init(text: "甲\n乙\n", paragraph: .numbered), .init(text: "正文\n"), .init(text: "丙", paragraph: .numbered)]))
        XCTAssertEqual(DiaryTypography.number(in: view.attributedText, at: 2), 2)
        XCTAssertEqual(DiaryTypography.number(in: view.attributedText, at: 7), 1)
    }
    func testMarkedChineseCompositionIsNotReplacedByFormattingOrFontRefresh() {
        let (controller, view) = editor([.init(text: "中文")])
        view.selectedRange = NSRange(location: 2, length: 0)
        view.setMarkedText("zuhe", selectedRange: NSRange(location: 4, length: 0))
        XCTAssertNotNil(view.markedTextRange)
        let before = NSAttributedString(attributedString: view.attributedText), selection = view.selectedRange
        controller.toggle(.italic); controller.setParagraph(.heading); controller.refreshFonts()
        XCTAssertEqual(view.attributedText, before); XCTAssertEqual(view.selectedRange, selection)
        view.unmarkText()
    }
    func testHeadingHierarchyAndSemanticFontRefreshRetainFormat() {
        let (controller, view) = editor([.init(text: "标题\n", paragraph: .heading), .init(text: "body", bold: true, italic: true)])
        let title = view.textStorage.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
        let body = view.textStorage.attribute(.font, at: 3, effectiveRange: nil) as! UIFont
        XCTAssertGreaterThan(title.pointSize, body.pointSize)
        let before = controller.runs(); controller.refreshFonts(); XCTAssertEqual(controller.runs(), before)
    }
    func testFormattingDoesNotSwallowPhotoAnchors() {
        let image = DiaryDocument.Photo(jpeg: Data(), width: 10, height: 10)
        let (controller, view) = editor([.init(text: "one\n"), .init(photo: image), .init(text: "\n后文")])
        view.selectedRange = NSRange(location: 0, length: view.textStorage.length)
        controller.toggle(.italic); controller.setParagraph(.quote)
        XCTAssertEqual(controller.runs().compactMap(\.photo), [image])
        XCTAssertEqual(controller.runs().map(\.text).joined(), "one\n\n后文")
        XCTAssertTrue(controller.runs().contains { $0.text == "\n" && $0.paragraph == .body })
    }
    func testParagraphUndoRestoresSubsequentTypingAndInitialBackspaceExitsWithoutDeletion() {
        let (controller, view) = editor([.init(text: "Keep 中文")])
        view.selectedRange = NSRange(location: 2, length: 0)
        controller.setParagraph(.numbered)
        XCTAssertEqual(DiaryTypography.kind(view.typingAttributes), .numbered)
        view.undoManager?.undo()
        XCTAssertEqual(DiaryTypography.kind(view.typingAttributes), .body)
        XCTAssertEqual(controller.runs().first?.paragraph, .body)
        view.undoManager?.redo()
        XCTAssertEqual(DiaryTypography.kind(view.typingAttributes), .numbered)
        view.selectedRange = NSRange(location: 0, length: 0)
        XCTAssertFalse(controller.shouldChange(view.selectedRange, replacement: ""))
        XCTAssertEqual(view.textStorage.string, "Keep 中文")
        XCTAssertEqual(controller.runs().first?.paragraph, .body)
    }

    func testFormattingInsideImageParagraphKeepsFutureInputParagraph() {
        let photo = DiaryDocument.Photo(jpeg: Data(), width: 10, height: 10)
        let (controller, view) = editor([.init(photo: photo), .init(text: "\nAfter")])
        view.selectedRange = NSRange(location: 1, length: 0)
        controller.setParagraph(.heading)
        XCTAssertEqual(DiaryTypography.kind(view.typingAttributes), .body)
        XCTAssertTrue(controller.shouldChange(view.selectedRange, replacement: "X"))
        view.insertText("X"); controller.textChanged()
        XCTAssertEqual(controller.runs().compactMap(\.photo), [photo])
        XCTAssertTrue(controller.runs().filter { $0.photo == nil && $0.text.contains("X") }.allSatisfy { $0.paragraph == .body })
        view.undoManager?.undo()
        XCTAssertEqual(controller.runs().compactMap(\.photo), [photo])
    }

    func testActualNativeInsertionAndCompositionKeepSemanticFormat() async {
        let controller = DiaryTextController(), view = DiaryNativeTextView(usingTextLayoutManager: false)
        let delegate = InputDelegate(controller)
        let window = UIWindow(frame: UIScreen.main.bounds), host = UIViewController()
        window.rootViewController = host; host.view.addSubview(view); view.frame = host.view.bounds
        controller.view = view; view.delegate = delegate; view.typingAttributes = controller.attributes
        view.prepareComposition = { controller.beginComposition() }
        view.finishComposition = { controller.textChanged() }
        window.makeKeyAndVisible(); view.becomeFirstResponder()
        defer { view.resignFirstResponder(); window.isHidden = true }
        controller.setParagraph(.heading); view.insertText("Heading")
        XCTAssertEqual(controller.runs().first?.paragraph, .heading)
        XCTAssertFalse(controller.runs().first?.bold ?? true)
        if controller.shouldChange(view.selectedRange, replacement: "\n") { view.insertText("\n") }
        await Task.yield()
        XCTAssertEqual(DiaryTypography.kind(view.typingAttributes), .body)
        XCTAssertFalse(DiaryTypography.run(view.typingAttributes).bold)
        controller.toggle(.bold); controller.toggle(.italic); controller.toggle(.underline)
        view.insertText("Body 😀")
        XCTAssertEqual(controller.runs().last?.paragraph, .body)
        XCTAssertTrue(controller.runs().last?.bold == true)
        XCTAssertTrue(controller.runs().last?.italic == true)
        XCTAssertTrue(controller.runs().last?.underline == true)
        view.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0))
        let range = view.selectedRange
        controller.setParagraph(.quote)
        XCTAssertEqual(view.selectedRange, range)
        XCTAssertNotNil(view.markedTextRange)
        view.setMarkedText("中文", selectedRange: NSRange(location: 2, length: 0)); view.unmarkText()
        XCTAssertTrue(view.text.contains("中文"))
        XCTAssertTrue(controller.runs().last?.bold == true)
        XCTAssertTrue(controller.runs().last?.italic == true)
        XCTAssertTrue(controller.runs().last?.underline == true)
        withExtendedLifetime(delegate) {}
    }

    func testParagraphStyleAtEndOfNonemptyFinalParagraphIsPersisted() {
        let (controller, view) = editor([.init(text: "An existing final paragraph 中文")])
        view.selectedRange = NSRange(location: view.textStorage.length, length: 0)
        controller.setParagraph(.numbered)
        XCTAssertEqual(controller.runs().first?.paragraph, .numbered)
        XCTAssertEqual(view.selectedRange.location, view.textStorage.length)
        view.undoManager?.undo(); XCTAssertEqual(controller.runs().first?.paragraph, .body)
    }

    func testHeadingSplitAndDifferentParagraphJoinNormalizeAndUndo() {
        let (controller, view) = editor([.init(text: "Heading", italic: true, paragraph: .heading)])
        view.selectedRange = NSRange(location: 3, length: 0)
        XCTAssertFalse(controller.shouldChange(view.selectedRange, replacement: "\n"))
        XCTAssertEqual(view.textStorage.string, "Hea\nding")
        XCTAssertEqual(controller.runs().last?.paragraph, .body)
        XCTAssertTrue(controller.runs().last?.italic == true)
        view.undoManager?.undo(); XCTAssertEqual(controller.runs(), [.init(text: "Heading", italic: true, paragraph: .heading)])
        view.attributedText = controller.attributed(document([.init(text: "A\n", paragraph: .bullet), .init(text: "B", bold: true)]))
        view.selectedRange = NSRange(location: 2, length: 0)
        XCTAssertFalse(controller.shouldChange(NSRange(location: 1, length: 1), replacement: ""))
        XCTAssertEqual(view.textStorage.string, "AB")
        XCTAssertTrue(controller.runs().allSatisfy { $0.paragraph == .bullet })
        XCTAssertTrue(controller.runs().last?.bold == true)
        XCTAssertEqual(DiaryTypography.kind(view.typingAttributes), .bullet)
        XCTAssertTrue(controller.shouldChange(view.selectedRange, replacement: "C"))
        view.insertText("C"); controller.textChanged()
        XCTAssertEqual(view.textStorage.string, "ACB")
        XCTAssertTrue(controller.runs().allSatisfy { $0.paragraph == .bullet })
        view.undoManager?.undo(); XCTAssertEqual(view.textStorage.string, "A\nB")
        XCTAssertEqual(controller.runs().last?.paragraph, .body)
    }

}
