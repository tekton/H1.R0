import Fluent

struct CreateSearch: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("searches")
            .field("id", .int, .identifier(auto: true))
            .field("md5hash", .string)
            .field("serial", .string)         // text column; JSON array stored here
            .field("new_tag", .string)
            .field("new_val", .string)
            .field("left", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "md5hash", name: "index_searches_on_md5hash")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("searches").delete()
    }
}
