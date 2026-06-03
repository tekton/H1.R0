import Fluent

struct CreateImage: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("images")
            .field("id", .int, .identifier(auto: true))
            .field("location", .string)
            .field("name", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("images").delete()
    }
}
