import Fluent

struct CreateExifDatum: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("exif_data")
            .field("id", .int, .identifier(auto: true))
            .field("parent", .int)            // legacy column, kept to match schema
            .field("tag", .string)
            .field("value", .string)
            .field("image_id", .int, .references("images", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("exif_data").delete()
    }
}
