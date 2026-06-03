import Vapor
import Queues
import Fluent

/// Background job that extracts EXIF data from a single JPEG file and stores it.
/// Mirrors the Rails `ExifWorker` (Sidekiq) which called `ExifParseController#exif_file`.
struct ExifJob: AsyncJob {
    struct Payload: Codable, Sendable {
        let filePath: String
        let imageID: Int
    }

    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        context.logger.info("ExifJob: \(payload.filePath) -> image \(payload.imageID)")
        try await ExifService.extract(
            path: payload.filePath,
            imageID: payload.imageID,
            db: context.application.db,
            logger: context.logger
        )
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        context.logger.error("ExifJob failed for \(payload.filePath): \(error)")
    }
}
