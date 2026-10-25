import SwiftUI

struct DiaryFormattingBar: View {
    @ObservedObject var text: DiaryTextController
    let status: String
    let addPhotos: () -> Void
    let importing: Bool
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "diary.format.text")).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        inline(.bold, icon: "bold", key: "diary.bold")
                        inline(.italic, icon: "italic", key: "diary.format.italic")
                        inline(.underline, icon: "underline", key: "diary.format.underline")
                        Spacer()
                    }
                    Text(String(localized: "diary.format.paragraph")).font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            paragraph(.body, icon: "text.alignleft", key: "diary.format.body")
                            paragraph(.heading, icon: "textformat.size.larger", key: "diary.format.heading")
                            paragraph(.bullet, icon: "list.bullet", key: "diary.format.bullet")
                            paragraph(.numbered, icon: "list.number", key: "diary.format.numbered")
                            paragraph(.quote, icon: "text.quote", key: "diary.format.quote")
                        }
                    }.scrollIndicators(.hidden)
                }.padding(.horizontal, 16).padding(.vertical, 8)
                Divider()
            }
            HStack(spacing: 8) {
                Button(action: addPhotos) { Image(systemName: "photo.badge.plus").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel(String(localized: "diary.addPhotos")).accessibilityIdentifier("diary.addPhotos")
                Button { text.focusBody(); text.refreshSelection(); expanded.toggle() } label: {
                    Text("Aa").font(.headline).frame(minWidth: 44, minHeight: 44)
                        .background(expanded ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 10))
                }.accessibilityLabel(String(localized: "diary.format.title"))
                    .accessibilityValue(String(localized: expanded ? "diary.format.expanded" : "diary.format.collapsed"))
                    .accessibilityIdentifier("diary.format")
                Button { text.view?.undoManager?.undo(); text.changed?(); text.refreshSelection() } label: {
                    Image(systemName: "arrow.uturn.backward").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel(String(localized: "diary.undo")).accessibilityIdentifier("diary.undo")
                Button { text.view?.undoManager?.redo(); text.changed?(); text.refreshSelection() } label: {
                    Image(systemName: "arrow.uturn.forward").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel(String(localized: "diary.format.redo")).accessibilityIdentifier("diary.redo")
                Spacer(minLength: 0)
                Button { text.hideKeyboard() } label: {
                    Image(systemName: "keyboard.chevron.compact.down").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel(String(localized: "diary.format.hideKeyboard")).accessibilityIdentifier("diary.hideKeyboard")
            }.padding(.horizontal, 12)
            Text(status).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                .accessibilityIdentifier("diary.status").padding(.horizontal, 12).padding(.bottom, 4)
        }.background(.bar).disabled(importing)
            // Keep editor chrome usable at accessibility sizes; document/title text
            // retain their full Dynamic Type range in the separate text view.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    private func inline(_ style: DiaryTextController.Inline, icon: String, key: String.LocalizationValue) -> some View {
        let state = text.inlineState[style] ?? .off
        return Button { text.toggle(style) } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                if state == .mixed { Image(systemName: "minus").font(.caption2) }
            }.frame(minWidth: 44, minHeight: 44)
                .background(state == .on ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.accessibilityLabel(String(localized: key))
            .accessibilityValue(String(localized: state == .mixed ? "diary.format.mixed" : state == .on ? "diary.format.on" : "diary.format.off"))
            .accessibilityAddTraits(state == .on ? .isSelected : [])
            .accessibilityIdentifier("diary.format." + style.rawValue)
    }
    private func paragraph(_ kind: DiaryDocument.Paragraph, icon: String, key: String.LocalizationValue) -> some View {
        Button { text.setParagraph(kind) } label: {
            Label(String(localized: key), systemImage: icon).font(.subheadline)
                .padding(.horizontal, 10).frame(minHeight: 44)
                .background(text.paragraphState == kind ? Color.accentColor.opacity(0.18) : .clear,
                            in: RoundedRectangle(cornerRadius: 10))
        }.accessibilityAddTraits(text.paragraphState == kind ? .isSelected : [])
            .accessibilityIdentifier("diary.paragraph." + kind.rawValue)
    }
}
