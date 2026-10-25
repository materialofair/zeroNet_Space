import Foundation

/// A versioned, local document. Only its encrypted encoding may reach persistent storage.
nonisolated struct DiaryDocument: Codable, Equatable, Sendable {
    var version = 1
    var id: UUID
    var title: String
    var runs: [Run]
    var entryDate = Date()
    var updatedAt: Date
    var baseModifiedAt: Date?
    var recoveryID = UUID()

    private enum CodingKeys: String, CodingKey {
        case version, id, title, runs, entryDate, updatedAt, baseModifiedAt, recoveryID
    }
    init(id: UUID, title: String, runs: [Run], entryDate: Date = Date(), updatedAt: Date,
         baseModifiedAt: Date? = nil, recoveryID: UUID = UUID()) {
        self.id = id; self.title = title; self.runs = runs; self.entryDate = entryDate
        self.updatedAt = updatedAt; self.baseModifiedAt = baseModifiedAt; self.recoveryID = recoveryID
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        runs = try values.decode([Run].self, forKey: .runs)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        entryDate = try values.decodeIfPresent(Date.self, forKey: .entryDate) ?? updatedAt
        baseModifiedAt = try values.decodeIfPresent(Date.self, forKey: .baseModifiedAt)
        recoveryID = try values.decodeIfPresent(UUID.self, forKey: .recoveryID) ?? id
    }

    struct Photo: Codable, Equatable, Sendable, Identifiable {
        var id: UUID = UUID()
        var jpeg: Data
        var width: Int
        var height: Int
    }

    struct Run: Codable, Equatable, Sendable {
        var text: String = ""
        var bold = false
        var italic = false
        var underline = false
        var paragraph: Paragraph = .body
        var photo: Photo?

        private enum CodingKeys: String, CodingKey { case text, bold, italic, underline, paragraph, photo }
        init(text: String = "", bold: Bool = false, italic: Bool = false, underline: Bool = false,
             paragraph: Paragraph = .body, photo: Photo? = nil) {
            self.text = text; self.bold = bold; self.italic = italic; self.underline = underline
            self.paragraph = paragraph; self.photo = photo
        }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            text = try values.decodeIfPresent(String.self, forKey: .text) ?? ""
            bold = try values.decodeIfPresent(Bool.self, forKey: .bold) ?? false
            italic = try values.decodeIfPresent(Bool.self, forKey: .italic) ?? false
            underline = try values.decodeIfPresent(Bool.self, forKey: .underline) ?? false
            paragraph = try values.decodeIfPresent(Paragraph.self, forKey: .paragraph) ?? .body
            photo = try values.decodeIfPresent(Photo.self, forKey: .photo)
        }
    }

    enum Paragraph: String, Codable, Equatable, Sendable, CaseIterable {
        case body, heading, bullet, numbered, quote
        var isList: Bool { self == .bullet || self == .numbered }
    }

    var plainText: String { runs.map(\.text).joined() }
    var photoCount: Int { runs.filter { $0.photo != nil }.count }
    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photoCount == 0
    }

    static func legacy(id: UUID, title: String, content: String, date: Date) -> Self {
        Self(id: id, title: title, runs: [Run(text: content)], entryDate: date, updatedAt: date)
    }
}
