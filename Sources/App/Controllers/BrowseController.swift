import Vapor
import Fluent
import SQLKit

/// Shared context structs for Leaf templates.

struct ExifTagCount: Content {
    let tag: String
    let value: String
    let count: Int
    let q: String   // md5 hash for the filter link
}

/// Tags excluded from the browse / filter tag lists (matches the ERB views).
let excludedTags: Set<String> = [
    "date_time_digitized",
    "user_comment",
    "date_time_original",
    "date_time",
    "subject_area",
]

enum BrowseHelpers {
    /// Aggregate exif_data into (tag, value, count) rows ordered by tag, and
    /// ensure a Search row exists for each single-tag filter (the Rails
    /// `filter_check` behaviour). Returns the rows decorated with their hash.
    static func tagCounts(on db: Database, imageIDs: [Int]? = nil) async throws -> [ExifTagCount] {
        let sql = db as! SQLDatabase

        var query = sql.select()
            .column("tag")
            .column("value")
            .column(SQLFunction("count", args: SQLLiteral.all), as: "count")
            .from("exif_data")

        if let imageIDs, !imageIDs.isEmpty {
            query = query.where("image_id", .in, SQLBind.group(imageIDs))
        }

        let rows = try await query
            .groupBy("tag")
            .groupBy("value")
            .orderBy("tag", .ascending)
            .all()

        var results: [ExifTagCount] = []
        for row in rows {
            let tag = (try? row.decode(column: "tag", as: String?.self)) ?? nil ?? ""
            let value = (try? row.decode(column: "value", as: String?.self)) ?? nil ?? ""
            let count = (try? row.decode(column: "count", as: Int.self)) ?? 0

            let hash = FilterHash.hash(tag: tag, value: value)
            try await ensureSearch(hash: hash, tagValues: [TagValue(tag: tag, value: value)], on: db)

            results.append(ExifTagCount(tag: tag, value: value, count: count, q: hash))
        }
        return results
    }

    /// Upsert a Search row keyed by md5hash (Rails `filter_check` / first_or_create).
    static func ensureSearch(hash: String, tagValues: [TagValue], on db: Database) async throws {
        let existing = try await Search.query(on: db)
            .filter(\.$md5hash == hash)
            .first()
        if existing == nil {
            let search = Search(md5hash: hash)
            search.tagValues = tagValues
            do {
                try await search.save(on: db)
            } catch {
                // A concurrent request may have inserted the same hash; the
                // unique index makes that safe to ignore.
            }
        }
    }
}

struct BrowseController {
    /// GET / — 4 random images + all exif tag/value counts with filter hashes.
    func index(req: Request) async throws -> View {
        let images = try await Image.query(on: req.db)
            .sort(.sql(raw: "RANDOM()"))
            .limit(4)
            .all()

        let exif = try await BrowseHelpers.tagCounts(on: req.db)

        let visible = exif.filter { !excludedTags.contains($0.tag) }

        struct Context: Content {
            let images: [Image]
            let exif: [ExifTagCount]
        }
        return try await req.view.render("browse", Context(images: images, exif: visible))
    }
}
