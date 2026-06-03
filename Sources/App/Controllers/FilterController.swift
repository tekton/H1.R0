import Vapor
import Fluent
import SQLKit

/// GET /filter/:hash_filter — show images matching a saved search (set of
/// tag/value pairs), plus the tag/value counts within that result set so the
/// user can drill further. Mirrors FilterController#hash_filter.
///
/// SECURITY: the original Rails code interpolated tag/value strings directly
/// into raw SQL (`(tag = '#{t["tag"]}' and value = '#{t["value"]}')`), which is
/// SQL-injectable. This rewrite uses parameterized SQLKit bindings instead.
struct FilterController {
    func hashFilter(req: Request) async throws -> View {
        guard let hash = req.parameters.get("hash_filter") else {
            throw Abort(.badRequest, reason: "hash_filter is required")
        }

        guard let search = try await Search.query(on: req.db)
            .filter(\.$md5hash == hash)
            .first() else {
            throw Abort(.notFound, reason: "No saved search for hash \(hash)")
        }

        let pairs = search.tagValues
        let sql = req.db as! SQLDatabase

        // Find image_ids that have ALL of the requested tag/value pairs.
        // SELECT image_id FROM exif_data
        //   INNER JOIN images ON exif_data.image_id = images.id
        //   WHERE (tag = $1 AND value = $2) OR (...)
        //   GROUP BY image_id HAVING count(*) = N
        var imageIDs: [Int] = []
        if !pairs.isEmpty {
            // Build a parameterized OR group of (tag = ? AND value = ?) clauses.
            var orExprs: [SQLExpression] = []
            for pair in pairs {
                let clause = SQLBinaryExpression(
                    left: SQLBinaryExpression(
                        left: SQLColumn("tag"),
                        op: SQLBinaryOperator.equal,
                        right: SQLBind(pair.tag)
                    ),
                    op: SQLBinaryOperator.and,
                    right: SQLBinaryExpression(
                        left: SQLColumn("value"),
                        op: SQLBinaryOperator.equal,
                        right: SQLBind(pair.value)
                    )
                )
                orExprs.append(SQLGroupExpression(clause))
            }
            let whereExpr = orExprs.dropFirst().reduce(orExprs[0]) { acc, next in
                SQLBinaryExpression(left: acc, op: SQLBinaryOperator.or, right: next)
            }

            let rows = try await sql.select()
                .column("image_id")
                .from("exif_data")
                .join("images", on: "exif_data.image_id", .equal, "images.id")
                .where(whereExpr)
                .groupBy("image_id")
                .having(
                    SQLFunction("count", args: SQLLiteral.all),
                    .equal,
                    SQLBind(pairs.count)
                )
                .all()

            imageIDs = rows.compactMap { try? $0.decode(column: "image_id", as: Int.self) }
        }

        // Load the matched images for display.
        var images: [Image] = []
        if !imageIDs.isEmpty {
            images = try await Image.query(on: req.db)
                .filter(\.$id ~~ imageIDs)
                .all()
        }

        // Tag/value counts within the matched set, each combined with the
        // existing filter pairs to build a (deeper) filter hash.
        var refined: [ExifTagCount] = []
        if !imageIDs.isEmpty {
            let counts = try await BrowseHelpers.tagCounts(on: req.db, imageIDs: imageIDs)
            for c in counts where !excludedTags.contains(c.tag) {
                var combined = pairs
                combined.append(TagValue(tag: c.tag, value: c.value))
                let h = FilterHash.hash(combined)
                try await BrowseHelpers.ensureSearch(hash: h, tagValues: combined, on: req.db)
                refined.append(ExifTagCount(tag: c.tag, value: c.value, count: c.count, q: h))
            }
        }

        struct Context: Content {
            let pairs: [TagValue]
            let images: [Image]
            let refined: [ExifTagCount]
        }
        return try await req.view.render(
            "filter/hash_filter",
            Context(pairs: pairs, images: images, refined: refined)
        )
    }
}
