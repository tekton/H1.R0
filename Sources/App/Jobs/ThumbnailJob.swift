import Vapor
import Queues

/// Background job that generates a 200x133 thumbnail for one image file.
/// Mirrors the Rails `ThumbnailsWorker` (Sidekiq) which called
/// `ThumbnailsController#create_thumbnail(folder, file)`.
struct ThumbnailJob: AsyncJob {
    struct Payload: Codable, Sendable {
        let folder: String
        let file: String
    }

    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        let base = context.application.directory.workingDirectory + "app/assets/images/"
        let source = base + payload.folder + "/" + payload.file
        let destination = base + "thumbnails/" + payload.folder + "/" + payload.file

        context.logger.info("ThumbnailJob: \(source) -> \(destination)")
        try ThumbnailService.generate(
            sourcePath: source,
            destinationPath: destination,
            logger: context.logger
        )
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        context.logger.error("ThumbnailJob failed for \(payload.folder)/\(payload.file): \(error)")
    }
}
