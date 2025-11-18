//
//  FilePreviewView.swift
//  ZeroNet-Space
//
//  文件预览视图
//  支持 PDF、文本等多种文件格式预览
//

import PDFKit
import SwiftUI

struct FilePreviewView: View {

    // MARK: - Properties

    let file: MediaItem

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @State private var isLoading: Bool = false
    @State private var isExporting: Bool = false
    @State private var fileContent: String?
    @State private var loadError: String?
    @State private var exportedURLs: [URL] = []
    @State private var showShareSheet = false
    @State private var exportError: String?
    @State private var showAlert = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                previewContent
            }
            .navigationTitle(file.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            shareFile()
                        } label: {
                            Label(
                                String(localized: "common.share"),
                                systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            deleteFile()
                        } label: {
                            Label(String(localized: "common.delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear(perform: loadFileContentIfNeeded)
        .alert(String(localized: "filePreview.alert.title"), isPresented: $showAlert) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(
            isPresented: $showShareSheet,
            onDismiss: {
                exportedURLs.removeAll()
            }
        ) {
            ShareSheet(items: exportedURLs)
        }
        .loadingOverlay(
            isShowing: isLoading || isExporting,
            message: isExporting
                ? String(localized: "filePreview.exporting")
                : String(localized: "filePreview.decrypting")
        )
    }

    // MARK: - Preview Content

    @ViewBuilder
    private var previewContent: some View {
        let ext = file.fileExtension.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        switch ext {
        case "pdf":
            pdfPreview
        case "txt", "md":
            textPreview
        default:
            unsupportedPreview
        }
    }

    // MARK: - PDF Preview

    @State private var pdfData: Data?
    @State private var isPdfLoading: Bool = false
    @State private var pdfLoadError: String?

    private var pdfPreview: some View {
        Group {
            if let data = pdfData {
                PDFReaderView(data: data)
            } else if isPdfLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(String(localized: "filePreview.decrypting"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = pdfLoadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text(String(localized: "filePreview.error.title"))
                        .font(.headline)

                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        loadPdfContent()
                    } label: {
                        Label(String(localized: "common.retry"), systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
                    .onAppear {
                        loadPdfContent()
                    }
            }
        }
    }

    private func loadPdfContent() {
        guard !isPdfLoading, pdfData == nil else { return }
        guard let password = authViewModel.sessionPassword, !password.isEmpty else {
            pdfLoadError = String(localized: "filePreview.error.noPassword")
            showAlert = true
            return
        }

        isPdfLoading = true
        pdfLoadError = nil

        Task {
            do {
                let storage = FileStorageService.shared
                let encryption = EncryptionService.shared
                let encryptedData = try storage.loadEncrypted(path: file.encryptedPath)
                let decryptedData = try encryption.decrypt(
                    encryptedData: encryptedData,
                    password: password
                )

                await MainActor.run {
                    self.pdfData = decryptedData
                    self.isPdfLoading = false
                }
            } catch {
                await MainActor.run {
                    self.pdfLoadError =
                        String(localized: "filePreview.error.decrypt")
                        + ": \(error.localizedDescription)"
                    self.isPdfLoading = false
                }
            }
        }
    }

    // MARK: - Text Preview

    private var textPreview: some View {
        ScrollView {
            if let error = loadError {
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let content = fileContent {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if isLoading {
                ProgressView(String(localized: "filePreview.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(String(localized: "filePreview.text.error"))
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Unsupported Preview

    private var unsupportedPreview: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(String(localized: "filePreview.unsupported"))
                .font(.headline)
                .foregroundColor(.secondary)

            Text(file.fileExtension.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray)
                .cornerRadius(8)

            Button {
                shareFile()
            } label: {
                Label(String(localized: "filePreview.export"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
    }

    // MARK: - Methods

    private func loadFileContentIfNeeded() {
        guard isTextFile, fileContent == nil, !isLoading else { return }
        guard let password = authViewModel.sessionPassword, !password.isEmpty else {
            loadError = String(localized: "filePreview.error.noPassword")
            showAlert = true
            return
        }

        isLoading = true
        loadError = nil

        Task {
            do {
                let storage = FileStorageService.shared
                let encryption = EncryptionService.shared
                let encryptedData = try storage.loadEncrypted(path: file.encryptedPath)
                let decryptedData = try encryption.decrypt(
                    encryptedData: encryptedData,
                    password: password
                )

                guard let text = String(data: decryptedData, encoding: .utf8) else {
                    throw NSError(
                        domain: "FilePreviewView",
                        code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: String(
                                localized: "filePreview.error.parseText")
                        ]
                    )
                }

                await MainActor.run {
                    self.fileContent = text
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.loadError = String(
                        format: String(localized: "filePreview.error.decryptFailed"),
                        error.localizedDescription)
                    self.isLoading = false
                    self.showAlert = true
                }
            }
        }
    }

    private func shareFile() {
        guard !isExporting else { return }
        guard let password = authViewModel.sessionPassword, !password.isEmpty else {
            exportError = String(localized: "filePreview.error.noPassword")
            return
        }

        isExporting = true
        exportError = nil

        ExportService.shared.exportItems([file], password: password) { result in
            switch result {
            case .success(let urls):
                exportedURLs = urls
                showShareSheet = true
            case .failure(let error):
                exportError = error.localizedDescription
                showAlert = true
            }

            isExporting = false
        }
    }

    private func deleteFile() {
        // TODO: 实现删除功能
        print("删除文件：\(file.fileName)")
        dismiss()
    }

    private var isTextFile: Bool {
        let ext = file.fileExtension.lowercased().trimmingCharacters(
            in: CharacterSet(charactersIn: "."))
        return ["txt", "md", "json", "csv", "log"].contains(ext)
    }

    private var alertMessage: String {
        if let exportError = exportError {
            return exportError
        }
        if let loadError = loadError {
            return loadError
        }
        return String(localized: "filePreview.error.generic")
    }
}

// MARK: - Preview

#Preview {
    let sampleFile = MediaItem(
        fileName: "sample.pdf",
        fileExtension: "pdf",
        fileSize: 512_000,
        type: .document,
        encryptedPath: "/path/to/file"
    )

    FilePreviewView(file: sampleFile)
        .environmentObject(AuthenticationViewModel())
}
