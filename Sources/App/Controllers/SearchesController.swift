import Vapor
import Fluent

struct SearchesController {
    /// GET /searches — list all saved searches.
    func index(req: Request) async throws -> View {
        let searches = try await Search.query(on: req.db).all()
        struct Context: Content { let searches: [Search] }
        return try await req.view.render("searches/index", Context(searches: searches))
    }

    /// GET /searches/new
    func new(req: Request) async throws -> View {
        struct Context: Content { let search: Search? }
        return try await req.view.render("searches/new", Context(search: nil))
    }

    struct SearchForm: Content {
        var md5hash: String?
        var serial: String?
    }

    /// POST /searches — create.
    func create(req: Request) async throws -> Response {
        let form = try req.content.decode(SearchForm.self)
        let search = Search(md5hash: form.md5hash ?? "")
        search.serial = form.serial
        try await search.save(on: req.db)
        return req.redirect(to: "/searches/\(search.id ?? 0)")
    }

    /// GET /searches/:id — show.
    func show(req: Request) async throws -> View {
        guard let id = req.parameters.get("id", as: Int.self),
              let search = try await Search.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        struct Context: Content { let search: Search }
        return try await req.view.render("searches/show", Context(search: search))
    }

    /// GET /searches/:id/edit
    func edit(req: Request) async throws -> View {
        guard let id = req.parameters.get("id", as: Int.self),
              let search = try await Search.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        struct Context: Content { let search: Search }
        return try await req.view.render("searches/edit", Context(search: search))
    }

    /// POST /searches/:id — update.
    func update(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: Int.self),
              let search = try await Search.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        let form = try req.content.decode(SearchForm.self)
        if let h = form.md5hash { search.md5hash = h }
        search.serial = form.serial
        try await search.save(on: req.db)
        return req.redirect(to: "/searches/\(id)")
    }

    /// POST /searches/:id/delete — destroy.
    func delete(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: Int.self),
              let search = try await Search.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        try await search.delete(on: req.db)
        return req.redirect(to: "/searches")
    }
}
