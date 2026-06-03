import Vapor
import Fluent

struct ImagesController {
    /// GET /images — list all images.
    func index(req: Request) async throws -> View {
        let images = try await Image.query(on: req.db).all()
        struct Context: Content { let images: [Image] }
        return try await req.view.render("images/index", Context(images: images))
    }

    /// GET /images/new
    func new(req: Request) async throws -> View {
        struct Context: Content { let image: Image? }
        return try await req.view.render("images/new", Context(image: nil))
    }

    struct ImageForm: Content {
        var id: Int?
        var location: String?
        var name: String?
    }

    /// POST /images — create.
    func create(req: Request) async throws -> Response {
        let form = try req.content.decode(ImageForm.self)
        let image = Image(id: form.id, location: form.location, name: form.name)
        try await image.save(on: req.db)
        return req.redirect(to: "/images/\(image.id ?? 0)")
    }

    /// GET /images/:id — show, including EXIF read straight from the file.
    func show(req: Request) async throws -> View {
        guard let id = req.parameters.get("id", as: Int.self),
              let image = try await Image.find(id, on: req.db) else {
            throw Abort(.notFound)
        }

        var exif: [ExifTagCount] = []
        // Read EXIF directly from the file (mirrors images#get_exif_data on show).
        if let location = image.location {
            let path = req.application.directory.workingDirectory + "app/assets/images/" + location
            if FileManager.default.fileExists(atPath: path) {
                let pairs = (try? ExifService.runExiftool(path: path, logger: req.logger)) ?? []
                exif = pairs.map { ExifTagCount(tag: $0.0, value: $0.1, count: 1, q: "") }
            }
        }

        struct Context: Content {
            let image: Image
            let exif: [ExifTagCount]
        }
        return try await req.view.render("images/show", Context(image: image, exif: exif))
    }

    /// GET /images/:id/edit
    func edit(req: Request) async throws -> View {
        guard let id = req.parameters.get("id", as: Int.self),
              let image = try await Image.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        struct Context: Content { let image: Image }
        return try await req.view.render("images/edit", Context(image: image))
    }

    /// POST /images/:id — update.
    func update(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: Int.self),
              let image = try await Image.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        let form = try req.content.decode(ImageForm.self)
        image.location = form.location
        image.name = form.name
        try await image.save(on: req.db)
        return req.redirect(to: "/images/\(id)")
    }

    /// POST /images/:id/delete — destroy.
    func delete(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: Int.self),
              let image = try await Image.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        try await image.delete(on: req.db)  // cascades to exif_data
        return req.redirect(to: "/images")
    }

    /// GET /images/:id/exif — EXIF read from the file on disk.
    func getExifData(req: Request) async throws -> View {
        guard let id = req.parameters.get("id", as: Int.self),
              let image = try await Image.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        var pairs: [(String, String)] = []
        if let location = image.location {
            let path = req.application.directory.workingDirectory + "app/assets/images/" + location
            if FileManager.default.fileExists(atPath: path) {
                pairs = (try? ExifService.runExiftool(path: path, logger: req.logger)) ?? []
            }
        }
        let exif = pairs.map { ExifTagCount(tag: $0.0, value: $0.1, count: 1, q: "") }
        struct Context: Content {
            let image: Image
            let exif: [ExifTagCount]
        }
        return try await req.view.render("images/get_exif_data", Context(image: image, exif: exif))
    }
}
