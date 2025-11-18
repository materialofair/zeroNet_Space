/*@ai:risk=2|deps=SecretNote|lines=160*/
//
//  NoteEditorView.swift
//  ZeroNet-Space
//
//  简洁的笔记编辑界面
//

import SwiftUI

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var title: String
    @State private var content: String
    @State private var lastAutoSaved: Date?
    @State private var autoSaveTask: Task<Void, Never>?

    let isNewNote: Bool
    let onSave: (String, String) -> Void
    let onCancel: (String, String) -> Void
    let onAutoSave: (String, String) -> Void

    init(
        initialTitle: String, initialContent: String, isNewNote: Bool,
        onSave: @escaping (String, String) -> Void, onCancel: @escaping (String, String) -> Void,
        onAutoSave: @escaping (String, String) -> Void
    ) {
        self._title = State(initialValue: initialTitle)
        self._content = State(initialValue: initialContent)
        self.isNewNote = isNewNote
        self.onSave = onSave
        self.onCancel = onCancel
        self.onAutoSave = onAutoSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "note.title.placeholder"), text: $title)
                        .textInputAutocapitalization(.sentences)
                        .focused($focusedField, equals: .title)
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $content)
                            .frame(minHeight: 240)
                            .focused($focusedField, equals: .body)

                        if content.isEmpty {
                            Text(String(localized: "note.content.placeholder"))
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.horizontal, 4)
                        }
                    }
                    infoRow
                }
            }
            .navigationTitle(
                title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? String(localized: "note.new")
                    : title
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        onCancel(title, content)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        onSave(title, content)
                        dismiss()
                    }
                    .disabled(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
        .onAppear {
            focusedField = isNewNote ? .body : .title
        }
        .onChange(of: title) { _ in scheduleAutoSave() }
        .onChange(of: content) { _ in scheduleAutoSave() }
    }

    private var infoRow: some View {
        HStack {
            Text(String(format: String(localized: "note.wordCount"), content.count))
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if let lastSaved = lastAutoSaved {
                Text(
                    String(format: String(localized: "note.lastSaved"), formatted(date: lastSaved))
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            } else {
                Text(String(localized: "note.autoSave.pending"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task.detached(priority: .background) { [title, content] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                onAutoSave(title, content)
                lastAutoSaved = Date()
            }
        }
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private enum Field {
        case title
        case body
    }
}

#Preview {
    NoteEditorView(
        initialTitle: "", initialContent: "", isNewNote: true, onSave: { _, _ in },
        onCancel: { _, _ in }, onAutoSave: { _, _ in })
}
