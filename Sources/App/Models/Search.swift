import Fluent
import Vapor

/// A single tag/value pair making up a saved search/filter.
struct TagValue: Codable, Equatable, Sendable {
    var tag: String
    var value: String
}

final class Search: Model, Content, @unchecked Sendable {
    static let schema = "searches"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "md5hash")
    var md5hash: String

    /// Raw text column. Rails stored YAML; this rewrite stores a canonical JSON
    /// array of {tag, value} objects. Use `tagValues` to read/write it decoded.
    @OptionalField(key: "serial")
    var serial: String?

    @OptionalField(key: "new_tag")
    var newTag: String?

    @OptionalField(key: "new_val")
    var newVal: String?

    @OptionalField(key: "left")
    var left: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: Int? = nil, md5hash: String, serial: String? = nil) {
        self.id = id
        self.md5hash = md5hash
        self.serial = serial
    }

    /// Decoded view of the `serial` JSON column.
    var tagValues: [TagValue] {
        get {
            guard let serial, let data = serial.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([TagValue].self, from: data)) ?? []
        }
        set {
            self.serial = Self.encode(newValue)
        }
    }

    /// Canonical JSON encoding: sorted by tag then value, stable key order.
    static func encode(_ tagValues: [TagValue]) -> String {
        let sorted = tagValues.sorted { a, b in
            a.tag == b.tag ? a.value < b.value : a.tag < b.tag
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sorted),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }
}
