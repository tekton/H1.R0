import Vapor
import Fluent

/// GET /exif_parse/:folder — scan a folder of JPEGs, ensure an Image row exists
/// for each, and dispatch an ExifJob to parse and store its EXIF data.
struct ExifParseController {
    func index(req: Request) async throws -> View {
        guard let folder = req.parameters.get("folder") else {
            throw Abort(.badRequest, reason: "folder is required")
        }

        let base = req.application.directory.workingDirectory + "app/assets/images/"
        let dir = base + folder

        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        var dispatched = 0

        for file in files where file.lowercased().hasSuffix(".jpg") {
            let fname = folder + "/" + file

            // first_or_create on location.
            let image: Image
            if let existing = try await Image.query(on: req.db)
                .filter(\.$location == fname)
                .first() {
                image = existing
            } else {
                image = Image(location: fname)
                try await image.save(on: req.db)
            }

            guard let imageID = image.id else { continue }
            let fullPath = dir + "/" + file
            try await req.queue.dispatch(
                ExifJob.self,
                ExifJob.Payload(filePath: fullPath, imageID: imageID)
            )
            dispatched += 1
        }

        struct Context: Content {
            let folder: String
            let dispatched: Int
        }
        return try await req.view.render("exif_parse/index", Context(folder: folder, dispatched: dispatched))
    }
}
