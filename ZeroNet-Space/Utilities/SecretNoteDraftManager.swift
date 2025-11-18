import Foundation

struct SecretNoteDraft: Codable {
    let title: String
    let content: String
    let updatedAt: Date
}

final class SecretNoteDraftManager {
    static let shared = SecretNoteDraftManager()
    private let draftKey = "secretSpace.draft"
    private init() {}

    func loadDraft() -> SecretNoteDraft? {
        guard let data = UserDefaults.standard.data(forKey: draftKey) else { return nil }
        return try? JSONDecoder().decode(SecretNoteDraft.self, from: data)
    }

    func saveDraft(title: String, content: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else {
            clearDraft()
            return
        }
        let draft = SecretNoteDraft(title: title, content: content, updatedAt: Date())
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: draftKey)
        }
    }

    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }
}
