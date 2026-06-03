import Vapor

/// GET /thumbnail/:folder — scan a folder of JPEGs and dispatch a ThumbnailJob
/// for each (mirrors ThumbnailsController#create_from_folder).
struct ThumbnailsController {
    func createFromFolder(req: Request) async throws -> View {
        guard let folder = req.parameters.get("folder") else {
            throw Abort(.badRequest, reason: "folder is required")
        }

        let base = req.application.directory.workingDirectory + "app/assets/images/"
        let dir = base + folder

        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        var dispatched = 0

        for file in files where file.lowercased().hasSuffix(".jpg") {
            try await req.queue.dispatch(
                ThumbnailJob.self,
                ThumbnailJob.Payload(folder: folder, file: file)
            )
            dispatched += 1
        }

        struct Context: Content {
            let folder: String
            let dispatched: Int
        }
        return try await req.view.render("thumbnails/create_from_folder", Context(folder: folder, dispatched: dispatched))
    }
}
