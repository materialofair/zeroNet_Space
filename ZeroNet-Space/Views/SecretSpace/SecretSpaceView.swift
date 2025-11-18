/*@ai:risk=2|deps=SecretNote|lines=200*/
//
//  SecretSpaceView.swift
//  ZeroNet-Space
//
//  隐藏空间记事本列表
//  轻量级的私密笔记体验
//

import SwiftData
import SwiftUI

struct SecretSpaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SecretNote.modifiedAt, order: .reverse) private var notes: [SecretNote]
    @EnvironmentObject private var guestModeManager: GuestModeManager

    @State private var editorState: EditorState?
    private let draftManager = SecretNoteDraftManager.shared

    var body: some View {
        NavigationStack {
            Group {
                notesContent
            }
            .navigationTitle(String(localized: "secretSpace.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if guestModeManager.isOwnerMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            createNote()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(item: $editorState) { state in
                NoteEditorView(
                    initialTitle: state.title,
                    initialContent: state.content,
                    isNewNote: state.isNew,
                    onSave: { title, content in
                        saveNote(
                            existing: state.note, title: title, content: content,
                            clearDraft: state.isNew)
                        editorState = nil
                    },
                    onCancel: { title, content in
                        if state.isNew {
                            draftManager.saveDraft(title: title, content: content)
                        }
                        editorState = nil
                    },
                    onAutoSave: { title, content in
                        if state.isNew {
                            draftManager.saveDraft(title: title, content: content)
                        } else {
                            saveNote(existing: state.note, title: title, content: content)
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var notesContent: some View {
        if guestModeManager.isGuestMode || notes.isEmpty {
            emptyState
        } else {
            List {
                if !pinnedNotes.isEmpty {
                    Section(String(localized: "secretSpace.section.pinned")) {
                        ForEach(pinnedNotes) { note in
                            NoteRow(note: note)
                                .onTapGesture {
                                    edit(note)
                                }
                        }
                        .onDelete { indexSet in
                            delete(indices: indexSet, from: pinnedNotes)
                        }
                    }
                }
                Section(String(localized: "secretSpace.section.notes")) {
                    ForEach(regularNotes) { note in
                        NoteRow(note: note)
                            .onTapGesture {
                                edit(note)
                            }
                    }
                    .onDelete(perform: delete)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var pinnedNotes: [SecretNote] {
        notes.filter { $0.isFavorite }
    }

    private var regularNotes: [SecretNote] {
        notes.filter { !$0.isFavorite }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(String(localized: "secretSpace.empty.title"))
                .font(.title3)
                .fontWeight(.medium)

            Text(String(localized: "secretSpace.empty.subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                createNote()
            } label: {
                Label(String(localized: "note.new"), systemImage: "plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Actions

    private func createNote() {
        let draft = draftManager.loadDraft()
        editorState = EditorState(
            note: nil, title: draft?.title ?? "", content: draft?.content ?? "", isNew: true)
    }

    private func edit(_ note: SecretNote) {
        editorState = EditorState(
            note: note, title: note.title, content: note.content, isNew: false)
    }

    private func delete(at offsets: IndexSet) {
        withAnimation {
            offsets.map { notes[$0] }.forEach(modelContext.delete)
            try? modelContext.save()
        }
    }

    private func delete(indices: IndexSet, from subset: [SecretNote]) {
        withAnimation {
            indices.map { subset[$0] }.forEach(modelContext.delete)
            try? modelContext.save()
        }
    }

    private func saveNote(
        existing: SecretNote?, title: String, content: String, clearDraft: Bool = false
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmed.isEmpty ? String(localized: "note.title.placeholder") : trimmed
        let now = Date()

        if let note = existing {
            note.title = finalTitle
            note.content = content
            note.modifiedAt = now
        } else {
            let newNote = SecretNote()
            newNote.title = finalTitle
            newNote.content = content
            newNote.createdAt = now
            newNote.modifiedAt = now
            modelContext.insert(newNote)
        }

        if clearDraft {
            draftManager.clearDraft()
        }

        do {
            try modelContext.save()
        } catch {
            print("保存笔记失败: \(error)")
        }
    }

}

private struct EditorState: Identifiable {
    let id = UUID()
    let note: SecretNote?
    let title: String
    let content: String
    let isNew: Bool
}

// MARK: - Note Row

private struct NoteRow: View {
    @Environment(\.modelContext) private var modelContext
    let note: SecretNote
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                if note.isFavorite {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Text(note.preview)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Text(note.formattedModifiedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: String(localized: "note.wordCount"), note.wordCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                note.isFavorite.toggle()
                try? modelContext.save()
            } label: {
                Label(
                    note.isFavorite
                        ? String(localized: "secretSpace.unpin")
                        : String(localized: "secretSpace.pin"),
                    systemImage: note.isFavorite ? "pin.slash" : "pin"
                )
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(note)
                try? modelContext.save()
            } label: {
                Label(String(localized: "common.delete"), systemImage: "trash")
            }
        }
    }
}

#Preview {
    SecretSpaceView()
        .modelContainer(for: SecretNote.self, inMemory: true)
}
