import SwiftUI

struct DiaryPDFShareItem: Identifiable {
    let id = UUID()
    let data: Data
    let fileName: String
}

@MainActor final class DiaryPDFExportModel: ObservableObject {
    @Published private(set) var generating = false
    @Published var share: DiaryPDFShareItem?
    @Published var needsVIP = false
    @Published var error: String?
    private weak var session: (any DiarySessionProviding)?
    private var isVIP: () -> Bool = { false }
    private var generation = UUID()
    private var request = UUID()
    private var task: Task<Void, Never>?
    private var cancellation: DiaryPDFCancellation?
    typealias Renderer = @Sendable (DiaryDocument, String, DiaryPDFCancellation) throws -> Data
    private let renderer: Renderer

    init(renderer: @escaping Renderer = DiaryPDFRenderer.render) { self.renderer = renderer }
    func configure(session: any DiarySessionProviding, isVIP: @escaping () -> Bool) {
        self.session = session; self.isVIP = isVIP; generation = session.presentationGeneration
    }
    var authorized: Bool { session?.canPresentSensitiveResult(generation) == true }
    func canShare(_ item: DiaryPDFShareItem) -> Bool {
        authorized && isVIP() && share?.id == item.id
    }
    func start(_ document: DiaryDocument) {
        guard authorized, !generating, share == nil else { return }
        guard isVIP() else { needsVIP = true; return }
        needsVIP = false; error = nil; generating = true; request = UUID()
        let current = request, token = DiaryPDFCancellation(), renderer = renderer
        cancellation = token
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .none
        let date = formatter.string(from: document.entryDate)
        task = Task { [weak self] in
            defer {
                if let self, self.request == current { self.generating = false; self.task = nil; self.cancellation = nil }
            }
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try renderer(document, date, token)
                }.value
                guard let self, self.request == current, !Task.isCancelled,
                      !token.isCancelled, self.authorized, self.isVIP() else { return }
                self.share = DiaryPDFShareItem(data: data, fileName: String(localized: "diary.pdf.fileName") + ".pdf")
            } catch is CancellationError {
                // Revocation never presents an old result or an error containing document data.
            } catch {
                guard let self, self.request == current, self.authorized, self.isVIP(), !token.isCancelled else { return }
                self.error = String(localized: "diary.pdf.failed")
            }
        }
    }
    func cancel() {
        request = UUID(); cancellation?.cancel(); cancellation = nil; task?.cancel(); task = nil
        generating = false; share = nil; needsVIP = false; error = nil
    }
}
