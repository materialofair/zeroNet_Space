import XCTest
import UIKit
import SwiftData
@testable import ZeroNet_Space

@MainActor final class DiaryPerformanceTests: XCTestCase {
    private func fixture() -> DiaryDocument {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1800), format: format).image { context in
            UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1800))
            UIColor.systemOrange.setStroke()
            for y in stride(from: 0, to: 1800, by: 17) {
                context.cgContext.move(to: CGPoint(x: 0, y: y)); context.cgContext.addLine(to: CGPoint(x: 1200, y: 1800 - y)); context.cgContext.strokePath()
            }
        }
        let jpeg = image.jpegData(compressionQuality: 0.82)!
        var runs: [DiaryDocument.Run] = []
        for _ in 0..<20 {
            runs.append(.init(text: String(repeating: "Fictional paragraph 中文 🌿.\n", count: 250)))
            runs.append(.init(photo: .init(jpeg: jpeg, width: 1200, height: 1800)))
            runs.append(.init(text: "\n"))
        }
        return DiaryDocument(id: UUID(), title: "Fictional performance fixture", runs: runs, updatedAt: Date())
    }
    func testLongTextWithTwentyPhotosSnapshotAndEncryptPerformance() {
        let document = fixture()
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            autoreleasepool {
                let controller = DiaryTextController(), view = UITextView(); controller.view = view
                view.attributedText = controller.attributed(document)
                let captured = controller.runs()
                XCTAssertEqual(captured.compactMap(\.photo).count, 20)
                var snapshot = document; snapshot.runs = captured
                let encrypted = try! DiaryStorage.shared.encrypt(snapshot, password: "Fictional-performance-7391")
                XCTAssertLessThan(encrypted.count, 80 * 1_024 * 1_024)
                controller.clear()
            }
        }
    }
    @MainActor private final class Session: DiarySessionProviding {
        var isAuthenticated = true
        var isDiaryOwner = true
        var sessionPassword: String? = "Fictional-performance-7391"
        var presentationGeneration = UUID()
        func canPresentSensitiveResult(_ generation: UUID) -> Bool { isAuthenticated && isDiaryOwner && generation == presentationGeneration }
    }
    func testDirtyTwentyPhotoFlushMeasuresGestureSaveGate() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DiaryFlushPerformance-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = DiaryStorage(directory: root)
        let container = try ModelContainer(for: SecretNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let session = Session(), document = fixture()
        let model = DiaryEditorModel(document: document, editing: true, storage: storage)
        model.configure(container: container, authentication: session)
        let view = UITextView(); model.text.view = view; view.attributedText = model.text.attributed(document)
        model.changed()
        let start = Date()
        XCTAssertTrue(model.flush())
        let elapsed = Date().timeIntervalSince(start)
        print("DIARY_DIRTY_FLUSH_SECONDS \(elapsed)")
        XCTAssertLessThan(elapsed, 5, "Simulator safety bound; this is not an oldest-hardware latency guarantee")
        XCTAssertTrue(try storage.recoveries(password: session.sessionPassword!).isEmpty)
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertEqual(try storage.decrypt(try XCTUnwrap(saved.encryptedDiary), password: session.sessionPassword!).photoCount, 20)
        model.text.clear()
        withExtendedLifetime(view) {}
    }

}
