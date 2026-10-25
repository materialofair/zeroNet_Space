import XCTest
import UIKit
import PDFKit
import UniformTypeIdentifiers
@testable import ZeroNet_Space

@MainActor private final class PDFTestSession: DiarySessionProviding {
    var isAuthenticated = true
    var isDiaryOwner = true
    var sessionPassword: String? = "Fictional-only"
    var presentationGeneration = UUID()
    func canPresentSensitiveResult(_ generation: UUID) -> Bool {
        isAuthenticated && isDiaryOwner && presentationGeneration == generation
    }
}
private nonisolated final class PDFRenderCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return storage }
    func add() { lock.lock(); storage += 1; lock.unlock() }
}

@MainActor private final class NativeGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
}

@MainActor final class DiaryPDFTests: XCTestCase {
    private func document() -> DiaryDocument {
        .legacy(id: UUID(), title: "虚构的两行标题\nA quiet afternoon 🌿", content: "中文正文与 emoji 😀\nA fictional afternoon.", date: Date())
    }
    private func wait(_ model: DiaryPDFExportModel) async {
        let done = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !model.generating }, object: nil)
        await fulfillment(of: [done], timeout: 10)
    }
    func testFreeMemberCannotStartRendererAndRestoredEntitlementCanExport() async {
        let count = PDFRenderCounter(), session = PDFTestSession()
        let model = DiaryPDFExportModel(renderer: { _, _, _ in count.add(); return Data("synthetic PDF".utf8) })
        var vip = false; model.configure(session: session, isVIP: { vip })
        model.start(document()); XCTAssertTrue(model.needsVIP); XCTAssertFalse(model.generating); XCTAssertNil(model.share)
        XCTAssertEqual(count.count, 0)
        vip = true; model.start(document()); await wait(model)
        XCTAssertEqual(count.count, 1); XCTAssertFalse(model.needsVIP)
        let item = try? XCTUnwrap(model.share); XCTAssertNotNil(item)
        if let item { XCTAssertTrue(model.canShare(item)); vip = false; XCTAssertFalse(model.canShare(item)) }
    }
    func testLockGuestAndExpiredEntitlementSuppressLateResults() async {
        for reason in 0..<3 {
            let session = PDFTestSession(), count = PDFRenderCounter()
            var vip = true
            let model = DiaryPDFExportModel(renderer: { _, _, _ in
                count.add(); Thread.sleep(forTimeInterval: 0.15); return Data("fictional PDF".utf8)
            })
            model.configure(session: session, isVIP: { vip }); model.start(document())
            if reason == 0 { session.presentationGeneration = UUID() }
            else if reason == 1 { session.isDiaryOwner = false }
            else { vip = false }
            await wait(model); XCTAssertNil(model.share); XCTAssertNil(model.error)
        }
    }
    func testCancelAndRenderFailureRetainSourceWithoutSharing() async {
        let session = PDFTestSession()
        let model = DiaryPDFExportModel(renderer: { _, _, token in
            Thread.sleep(forTimeInterval: 0.1)
            if token.isCancelled { throw CancellationError() }
            throw CocoaError(.fileWriteOutOfSpace)
        })
        model.configure(session: session, isVIP: { true })
        let original = document(); model.start(original); model.cancel()
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNil(model.share); XCTAssertNil(model.error); XCTAssertFalse(model.generating)
        model.start(original); await wait(model); XCTAssertNotNil(model.error); XCTAssertNil(model.share)
        XCTAssertEqual(original.plainText, document().plainText)
    }
    func testProviderServesInMemoryPDFWithoutAnAppTemporaryFile() async throws {
        let data = try DiaryPDFRenderer.render(document(), date: "2026-10-23")
        let item = DiaryPDFShareItem(data: data, fileName: "Fictional.pdf")
        let provider = DiaryPDFShareSheet.provider(for: item)
        XCTAssertEqual(provider.suggestedName, "Fictional.pdf")
        let returned = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown)) }
            }
        }
        XCTAssertEqual(returned, data)
    }
    func testMultilingualRichMultiPagePDFRendersEveryPageAndKeepsSelectableText() throws {
        var entry = document()
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 1800), format: format).image { ctx in
            for row in 0..<18 {
                (row % 2 == 0 ? UIColor.systemTeal : UIColor.systemOrange).setFill()
                ctx.fill(CGRect(x: 0, y: row * 100, width: 200, height: 100))
                ("Fictional image strip \(row)" as NSString).draw(at: CGPoint(x: 8, y: row * 100 + 40), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
            }
        }
        let photo = DiaryDocument.Photo(jpeg: try XCTUnwrap(image.jpegData(compressionQuality: 0.8)), width: 200, height: 1800)
        entry.runs = [.init(text: "春日散步 Spring walk 🌿\n", paragraph: .heading),
            .init(text: "局部粗体 Bold ", bold: true), .init(text: "粗斜叠加 Combined", bold: true, italic: true),
            .init(text: " 下划线 Underline\n", underline: true),
            .init(text: "第一项 苹果\n第二项 云朵\n", paragraph: .bullet),
            .init(text: "First step\nSecond step\n", paragraph: .numbered),
            .init(text: "这是一段虚构引用。A fictional quotation.\n", paragraph: .quote), .init(photo: photo),
            .init(text: "\n两张图片之间的文字 Between two photos.\n"), .init(photo: photo),
            .init(text: "\n" + (1...75).map { "段落\($0) — 中文与 English 😀，虚构内容用于分页验证。\n" }.joined()),
            .init(text: "尾部小标题 Final heading\n", paragraph: .heading), .init(text: "最终尾行 END-OF-FICTIONAL-DIARY")]
        let data = try DiaryPDFRenderer.render(entry, date: "2026年10月23日")
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(pdf.pageCount, 4)
        let text = try XCTUnwrap(pdf.string)
        for expected in ["虚构的两行标题", "第一项", "Second step", "两张图片之间", "段落75", "END-OF-FICTIONAL-DIARY"] {
            XCTAssertTrue(text.contains(expected), "Missing selectable text: \(expected)")
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: UTType.pdf.identifier)
        attachment.name = "Fictional-rich-diary.pdf"; attachment.lifetime = .keepAlways; add(attachment)
        for index in 0..<pdf.pageCount {
            let page = try XCTUnwrap(pdf.page(at: index))
            let image = page.thumbnail(of: CGSize(width: 900, height: 1273), for: .mediaBox)
            XCTAssertGreaterThan(image.size.width, 0)
            let screenshot = XCTAttachment(image: image); screenshot.name = "rich-pdf-page-\(index + 1)"; screenshot.lifetime = .keepAlways; add(screenshot)
            XCTAssertFalse((page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?.hasPrefix("SealedPocket-Demo-") == true {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FictionalPDFEvidence")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent("Fictional-rich-diary.pdf"))
            for index in 0..<pdf.pageCount {
                let image = try XCTUnwrap(pdf.page(at: index)).thumbnail(of: CGSize(width: 900, height: 1273), for: .mediaBox)
                try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("page-\(index + 1).png"))
            }
        }
    }
    func testEmptyTitleLegacyTextCancellationAndInvalidImage() throws {
        var entry = document(); entry.title = ""
        let pdf = try XCTUnwrap(PDFDocument(data: DiaryPDFRenderer.render(entry, date: "2026-10-23")))
        XCTAssertTrue(pdf.string?.contains("中文正文") == true)
        let token = DiaryPDFCancellation(); token.cancel()
        XCTAssertThrowsError(try DiaryPDFRenderer.render(entry, date: "2026", cancellation: token))
        entry.runs.append(.init(photo: .init(jpeg: Data([0, 1]), width: 1, height: 1)))
        XCTAssertThrowsError(try DiaryPDFRenderer.render(entry, date: "2026"))
    }
    func testNativeBackRecognizerVetoAndRestorationAreScopedToEditor() throws {
        let nav = UINavigationController(), owner = UIViewController(), host = DiaryBackGesture.Host()
        let root = UIViewController(); nav.viewControllers = [root, owner]; nav.loadViewIfNeeded()
        owner.addChild(host); owner.view.addSubview(host.view); host.didMove(toParent: owner)
        let coordinator = DiaryBackGesture.Coordinator()
        let gesture = try XCTUnwrap(nav.interactivePopGestureRecognizer)
        let nativeRules = NativeGestureDelegate()
        gesture.delegate = nativeRules
        let originalAction = UIAction(title: "Original", identifier: .init("fictional.original")) { _ in }
        owner.navigationItem.backAction = originalAction
        let previous = gesture.delegate; let enabled = gesture.isEnabled
        var exits = 0; coordinator.onBack = { exits += 1 }
        coordinator.attach(from: host); coordinator.canLeave = { false }
        XCTAssertEqual((coordinator as any UIGestureRecognizerDelegate).gestureRecognizer?(gesture,
            shouldRecognizeSimultaneouslyWith: UITapGestureRecognizer()), true)
        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(gesture))
        coordinator.requestBack(); XCTAssertEqual(exits, 0)
        coordinator.canLeave = { true }; XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(gesture))
        coordinator.requestBack(); XCTAssertEqual(exits, 1)
        coordinator.restore(); XCTAssertTrue(gesture.delegate === previous); XCTAssertEqual(gesture.isEnabled, enabled)
        XCTAssertEqual(owner.navigationItem.backAction?.identifier, originalAction.identifier)
    }
    func testNativeContentPopOnlyStartsAtLeadingMarginAndHonorsSaveVeto() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        typealias Gate = DiaryBackGesture.Coordinator.LeadingContentGate
        XCTAssertTrue(Gate.beginsAtLeadingEdge(in: view, point: CGPoint(x: 18, y: 100)))
        XCTAssertFalse(Gate.beginsAtLeadingEdge(in: view, point: CGPoint(x: 40, y: 100)))
        XCTAssertFalse(Gate.beginsAtLeadingEdge(in: view, point: CGPoint(x: -1, y: 100)))
        view.semanticContentAttribute = .forceRightToLeft
        XCTAssertTrue(Gate.beginsAtLeadingEdge(in: view, point: CGPoint(x: 382, y: 100)))
        XCTAssertFalse(Gate.beginsAtLeadingEdge(in: view, point: CGPoint(x: 18, y: 100)))
        let gate = Gate(), pan = UIPanGestureRecognizer()
        gate.canBegin = { false }; XCTAssertFalse(gate.gestureRecognizerShouldBegin(pan))
        gate.canBegin = { true }; XCTAssertTrue(gate.gestureRecognizerShouldBegin(pan))
    }
}
