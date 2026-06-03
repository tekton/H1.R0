import Fluent
import Vapor

final class ExifDatum: Model, Content, @unchecked Sendable {
    static let schema = "exif_data"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Parent(key: "image_id")
    var image: Image

    @OptionalField(key: "tag")
    var tag: String?

    @OptionalField(key: "value")
    var value: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: Int? = nil, imageID: Int, tag: String?, value: String?) {
        self.id = id
        self.$image.id = imageID
        self.tag = tag
        self.value = value
    }
}
