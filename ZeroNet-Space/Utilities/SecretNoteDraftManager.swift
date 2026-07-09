import Foundation

struct SecretNoteDraft: Codable {
    let title: String
    let content: String
    let updatedAt: Date
}

/// 草稿属于未落库的私密内容，存 Keychain（仅本机、设备解锁后可用），
/// 不能明文写入 UserDefaults（明文 plist 会进入未加密备份）
final class SecretNoteDraftManager {
    static let shared = SecretNoteDraftManager()
    private let legacyDraftKey = "secretSpace.draft"
    private let keychainService = KeychainService.shared

    private init() {
        migrateLegacyDraftFromUserDefaults()
    }

    func loadDraft() -> SecretNoteDraft? {
        guard let data = keychainService.loadSecretNoteDraft() else { return nil }
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
            keychainService.saveSecretNoteDraft(data)
        }
    }

    func clearDraft() {
        keychainService.deleteSecretNoteDraft()
    }

    /// 旧版本把草稿明文存在 UserDefaults，迁移到 Keychain 后删除明文副本。
    /// Keychain 写入可能失败（如锁屏时冷启动），确认迁移成功才删除旧数据，
    /// 失败则保留旧值，等下次启动重试
    private func migrateLegacyDraftFromUserDefaults() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: legacyDraftKey) else { return }
        let migrated =
            keychainService.loadSecretNoteDraft() != nil
            || keychainService.saveSecretNoteDraft(data)
        if migrated {
            defaults.removeObject(forKey: legacyDraftKey)
        }
    }
}
