import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var authentication: AuthenticationViewModel
    @EnvironmentObject private var guest: GuestModeManager
    @StateObject private var model: DiaryEditorModel
    @StateObject private var pdf = DiaryPDFExportModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var picker = false
    @State private var insertion = NSRange(location: 0, length: 0)
    @State private var selectedPhoto: DiaryDocument.Photo?
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var photoActions = false
    @State private var fullPhoto: DiaryDocument.Photo?
    @State private var moving: UUID?

    init(document: DiaryDocument, editing: Bool = false, legacy: Bool = false, legacyDraft: Bool = false,
         expectedModifiedAt: Date? = nil, sourceRecoveryID: UUID? = nil) {
        _model = StateObject(wrappedValue: DiaryEditorModel(document: document, editing: editing,
            legacy: legacy, clearLegacyDraft: legacyDraft, expectedModifiedAt: expectedModifiedAt,
            sourceRecoveryID: sourceRecoveryID))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !model.revoked {
                if model.editing && model.isLegacy {
                    Text(String(localized: "diary.legacy"))
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 4)
                }
                if let source = moving {
                    HStack {
                        Text(String(localized: "diary.moveHint")).font(.caption)
                        Spacer()
                        Button(String(localized: "diary.moveHere")) {
                            model.text.move(photoID: source, to: model.text.selection.location); moving = nil
                        }.accessibilityIdentifier("diary.moveHere")
                        Button(String(localized: "common.cancel")) { moving = nil }
                    }.padding(12)
                }
                DiaryTextView(controller: model.text, document: model.document, editing: model.editing, heading: AnyView(heading),
                    onChange: { [weak model] in model?.changed() }, onPhoto: { range, photo in
                        guard model.authorized else { return }
                        if model.editing {
                            selectedRange = range; selectedPhoto = photo; photoActions = true
                        } else { fullPhoto = photo }
                    })
                    .frame(maxWidth: 800).frame(maxWidth: .infinity)
                    .disabled(model.importing)
                if model.importing {
                    HStack {
                        ProgressView(value: Double(model.importProgress), total: Double(max(1, model.importTotal)))
                        Text("\(model.importProgress)/\(model.importTotal)").font(.caption).monospacedDigit()
                        Button(String(localized: "common.cancel")) { model.cancelImport() }
                    }.padding()
                }
                if pdf.generating {
                    HStack {
                        ProgressView()
                        Text(String(localized: "diary.pdf.generating")).font(.caption)
                        Spacer()
                        Button(String(localized: "common.cancel")) { pdf.cancel() }
                    }.padding(12).accessibilityIdentifier("diary.pdf.progress")
                }
                if model.editing { editingToolbar }
            }
        }
        .modifier(DiaryPrivateInput())
        .background(scheme == .dark ? Color(uiColor: .systemBackground) : Color(red: 1, green: 0.99, blue: 0.97))
        .navigationBarTitleDisplayMode(.inline)
        .background(DiaryBackGesture(canLeave: {
            guard model.authorized, !model.importing else { return false }
            pdf.cancel()
            return model.flush()
        }, onBack: { dismiss() }).frame(width: 0, height: 0))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard model.authorized else { return }
                    model.text.hideKeyboard()
                    pdf.start(model.snapshot())
                } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel(String(localized: "diary.pdf.export"))
                    .accessibilityIdentifier("diary.exportPDF")
                    .disabled(model.importing || model.revoked || pdf.generating)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: model.editing ? "common.done" : "diary.edit")) {
                    if model.editing {
                        if model.flush() { model.editing = false; moving = nil }
                    } else { model.editing = true }
                }.accessibilityIdentifier("diary.editDone").disabled(model.importing || model.revoked)
            }
        }
        .sheet(isPresented: $picker) {
            DiaryPhotoPicker(limit: max(1, 20 - model.snapshot().photoCount)) { results in
                picker = false
                if results.isEmpty, model.authorized {
                    model.text.view?.selectedRange = insertion
                    model.text.view?.becomeFirstResponder()
                }
                model.beginImport(results, at: insertion)
            }
        }
        .sheet(isPresented: $pdf.needsVIP) { DiaryPDFVIPView() }
        .sheet(item: $pdf.share) { item in
            DiaryPDFShareSheet(item: item, isAllowed: { pdf.canShare(item) }, finished: { pdf.cancel() })
        }
        .fullScreenCover(item: $fullPhoto) { photo in
            DiaryFullPhotoView(photo: photo)
        }
        .confirmationDialog(String(localized: "diary.photoActions"), isPresented: $photoActions, titleVisibility: .visible) {
            Button(String(localized: "diary.viewPhoto")) { fullPhoto = selectedPhoto }
            Button(String(localized: "diary.writeAbove")) { model.text.write(above: true, imageRange: selectedRange) }
            Button(String(localized: "diary.writeBelow")) { model.text.write(above: false, imageRange: selectedRange) }
            Button(String(localized: "diary.movePhoto")) { moving = selectedPhoto?.id; model.text.view?.becomeFirstResponder() }
            Button(String(localized: "diary.removePhoto"), role: .destructive) {
                model.text.replace(selectedRange, with: NSAttributedString(string: "")); selectedPhoto = nil
            }
            Button(String(localized: "common.cancel"), role: .cancel) { selectedPhoto = nil }
        }
        .alert(String(localized: "common.error"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            if model.conflicted { Button(String(localized: "diary.saveCopy")) { _ = model.saveAsCopy() } }
            if model.canRetryImport { Button(String(localized: "diary.retry")) { model.retryImport() } }
            Button(String(localized: "common.ok"), role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .onAppear {
            model.configure(container: context.container, authentication: authentication)
            pdf.configure(session: authentication, isVIP: { AppSettings.shared.isVIP })
        }
        .onChange(of: pdf.error) { _, error in if let error { model.error = error } }
        .onChange(of: settings.hasUnlockedUnlimited) { _, value in if !value { pdf.cancel() } }
        .onChange(of: model.document.title) { _, _ in model.changed() }
        .onChange(of: guest.currentMode) { _, mode in
            if mode != .owner {
                picker = false; photoActions = false; fullPhoto = nil; selectedPhoto = nil; moving = nil
                model.revoke()
                pdf.cancel()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                _ = model.flush(explicitCommit: false)
                if pdf.share == nil { pdf.cancel() }
            }
        }
        .onDisappear {
            _ = model.flush(explicitCommit: false); model.cancelImport()
            if pdf.share == nil { pdf.cancel() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vaultWillLock)) { _ in
            picker = false; photoActions = false; fullPhoto = nil; selectedPhoto = nil; moving = nil
            model.revoke()
            pdf.cancel()
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.document.entryDate, format: .dateTime.year().month().day())
                .font(.footnote).foregroundStyle(.secondary)
            if model.editing {
                TextField(String(localized: "diary.optionalTitle"), text: $model.document.title, axis: .vertical)
                    .font(.title.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true).autocorrectionDisabled()
                    .accessibilityIdentifier("diary.title")
            } else if !model.document.title.isEmpty {
                Text(model.document.title).font(.title.weight(.semibold)).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("diary.title.read")
            }
        }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)
            .frame(maxWidth: 800, alignment: .leading).frame(maxWidth: .infinity)
    }

    private var editingToolbar: some View {
        DiaryFormattingBar(text: model.text, status: model.status, addPhotos: {
            guard model.snapshot().photoCount < 20 else { return }
            insertion = model.text.selection
            model.text.hideKeyboard(); picker = true
        }, importing: model.importing)
    }

}

private struct DiaryFullPhotoView: View {
    let photo: DiaryDocument.Photo
    @Environment(\.dismiss) private var dismiss
    @State private var revoked = false
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    if !revoked, let image = UIImage(data: photo.jpeg) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(width: geometry.size.width)
                            .accessibilityLabel(String(localized: "diary.viewPhoto"))
                    }
                }.background(Color.black)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.done")) { dismiss() }.accessibilityIdentifier("diary.photoDone")
            } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vaultWillLock)) { _ in revoked = true; dismiss() }
    }
}

private struct DiaryPrivateInput: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *) { content.writingToolsBehavior(.disabled) }
        else { content }
    }
}
