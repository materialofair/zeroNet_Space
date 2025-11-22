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
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?

    @State private var title: String
    @State private var content: String
    @State private var lastAutoSaved: Date?
    @State private var autoSaveTask: Task<Void, Never>?

    let isNewNote: Bool
    let onSave: (String, String) -> Void
    let onAutoSave: (String, String) -> Void

    init(
        initialTitle: String, initialContent: String, isNewNote: Bool,
        onSave: @escaping (String, String) -> Void,
        onAutoSave: @escaping (String, String) -> Void
    ) {
        self._title = State(initialValue: initialTitle)
        self._content = State(initialValue: initialContent)
        self.isNewNote = isNewNote
        self.onSave = onSave
        self.onAutoSave = onAutoSave
    }

    var body: some View {
        ZStack {
            // 纸张风格背景
            paperBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 标题输入框
                titleSection

                Divider()
                    .padding(.horizontal)

                // 内容编辑器
                contentSection

                // 底部工具栏
                bottomToolbar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    onSave(title, content)
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .onAppear {
            focusedField = .content
        }
        .onChange(of: title) { _ in scheduleAutoSave() }
        .onChange(of: content) { _ in scheduleAutoSave() }
    }

    // MARK: - View Components

    /// 纸张风格背景
    private var paperBackground: some View {
        Group {
            if colorScheme == .light {
                Color(red: 1.0, green: 0.98, blue: 0.94)  // 米黄色纸张
            } else {
                Color(red: 0.15, green: 0.15, blue: 0.15)  // 深灰色
            }
        }
    }

    /// 标题输入区域
    private var titleSection: some View {
        TextField(String(localized: "note.title.placeholder"), text: $title)
            .font(.system(size: 24, weight: .bold))
            .textInputAutocapitalization(.sentences)
            .focused($focusedField, equals: .title)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.clear)
    }

    /// 内容编辑区域
    private var contentSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $content)
                .font(.system(size: 17))
                .lineSpacing(6)
                .focused($focusedField, equals: .content)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

            if content.isEmpty {
                Text(String(localized: "note.content.placeholder"))
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .allowsHitTesting(false)
            }
        }
    }

    /// 底部工具栏
    private var bottomToolbar: some View {
        HStack {
            // 字数统计
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption2)
                Text(String(format: String(localized: "note.wordCount"), content.count))
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            Spacer()

            // 自动保存状态
            if let lastSaved = lastAutoSaved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(
                        String(
                            format: String(localized: "note.lastSaved"),
                            formatted(date: lastSaved))
                    )
                    .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            colorScheme == .light
                ? Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.8)
                : Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.8)
        )
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
        case content
    }
}

#Preview {
    NavigationStack {
        NoteEditorView(
            initialTitle: "",
            initialContent: "",
            isNewNote: true,
            onSave: { _, _ in },
            onAutoSave: { _, _ in }
        )
    }
}
