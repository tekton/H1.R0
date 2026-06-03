import Fluent
import Vapor

final class Image: Model, Content, @unchecked Sendable {
    static let schema = "images"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "location")
    var location: String?

    @OptionalField(key: "name")
    var name: String?

    @Children(for: \.$image)
    var exifData: [ExifDatum]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: Int? = nil, location: String? = nil, name: String? = nil) {
        self.id = id
        self.location = location
        self.name = name
    }
}
