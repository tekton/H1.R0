import Vapor
import Fluent

struct ExifDataController {
    /// GET /exif_data — tag/value counts with filter hashes (same as browse list).
    func index(req: Request) async throws -> View {
        let exif = try await BrowseHelpers.tagCounts(on: req.db)
        struct Context: Content { let exif: [ExifTagCount] }
        return try await req.view.render("exif_data/index", Context(exif: exif))
    }

    /// GET /exif_data/new
    func new(req: Request) async throws -> View {
        struct Context: Content { let datum: ExifDatum? }
        return try await req.view.render("exif_data/new", Context(datum: nil))
    }

    struct ExifForm: Content {
        var image_id: Int?
        var tag: String?
        var value: String?
    }

    /// POST /exif_data — create.
    func create(req: Request) async throws -> Response {
        let form = try req.content.decode(ExifForm.self)
        guard let imageID = form.image_id else {
            throw Abort(.badRequest, reason: "image_id is required")
        }
        let datum = ExifDatum(imageID: imageID, tag: form.tag, value: form.value)
        try await datum.save(on: req.db)
        return req.redirect(to: "/exif_data/\(datum.id ?? 0)")
    }

    /// GET /exif_data/:id — show.
    func show(req: Request) async throws -> View {
        guard let id = req.parameters.get("id", as: Int.self),
              let datum = try await ExifDatum.query(on: req.db)
                .filter(\.$id == id)
                .with(\.$image)
                .first() else {
            throw Abort(.notFound)
        }
        struct Context: Content { let datum: ExifDatum }
        return try await req.view.render("exif_data/show", Context(datum: datum))
    }

    /// GET /exif_data/:id/edit
    func edit(req: Request) async throws -> View {
        guard let id = req.parameters.get("id", as: Int.self),
              let datum = try await ExifDatum.query(on: req.db)
                .filter(\.$id == id)
                .with(\.$image)
                .first() else {
            throw Abort(.notFound)
        }
        struct Context: Content { let datum: ExifDatum }
        return try await req.view.render("exif_data/edit", Context(datum: datum))
    }

    /// POST /exif_data/:id — update.
    func update(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: Int.self),
              let datum = try await ExifDatum.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        let form = try req.content.decode(ExifForm.self)
        if let imageID = form.image_id { datum.$image.id = imageID }
        datum.tag = form.tag
        datum.value = form.value
        try await datum.save(on: req.db)
        return req.redirect(to: "/exif_data/\(id)")
    }

    /// POST /exif_data/:id/delete — destroy.
    func delete(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: Int.self),
              let datum = try await ExifDatum.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        try await datum.delete(on: req.db)
        return req.redirect(to: "/exif_data")
    }
}
