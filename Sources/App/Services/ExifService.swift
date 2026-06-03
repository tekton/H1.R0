import Foundation
import Fluent
import Vapor
import SQLKit

/// Extracts EXIF metadata from a JPEG by shelling out to `exiftool -json`,
/// then upserts one `ExifDatum` row per tag/value pair for the given image.
enum ExifService {
    struct ExifError: Error { let message: String }

    /// Run exiftool on `path` and store the resulting tags against `imageID`.
    static func extract(path: String, imageID: Int, db: Database, logger: Logger) async throws {
        let tags = try runExiftool(path: path, logger: logger)

        for (tag, value) in tags {
            // Skip non-meaningful empties.
            guard !value.isEmpty else { continue }

            // Upsert semantics: there is no unique constraint on exif_data,
            // so check-then-insert to avoid duplicating identical rows.
            let existing = try await ExifDatum.query(on: db)
                .filter(\.$image.$id == imageID)
                .filter(\.$tag == tag)
                .filter(\.$value == value)
                .first()

            if existing == nil {
                let datum = ExifDatum(imageID: imageID, tag: tag, value: value)
                try await datum.save(on: db)
            }
        }
    }

    /// Invoke `exiftool -json <path>` and parse the resulting tag dictionary.
    /// Returns an array of (tag, value) preserving deterministic ordering.
    static func runExiftool(path: String, logger: Logger) throws -> [(String, String)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["exiftool", "-json", "-n", path]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ExifError(message: "exiftool exited \(process.terminationStatus): \(err)")
        }

        // exiftool -json emits an array with a single object per file.
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first else {
            logger.warning("exiftool produced no JSON object for \(path)")
            return []
        }

        var result: [(String, String)] = []
        for key in first.keys.sorted() {
            // SourceFile is exiftool bookkeeping, not real EXIF metadata.
            if key == "SourceFile" { continue }
            let raw = first[key]
            result.append((key, stringify(raw)))
        }
        return result
    }

    /// Convert an arbitrary JSON value from exiftool into a stable string.
    private static func stringify(_ value: Any?) -> String {
        switch value {
        case let s as String:
            return s
        case let n as NSNumber:
            return n.stringValue
        case let arr as [Any]:
            return arr.map { stringify($0) }.joined(separator: ", ")
        case let dict as [String: Any]:
            return dict.keys.sorted().map { "\($0): \(stringify(dict[$0]))" }.joined(separator: ", ")
        case .none, is NSNull:
            return ""
        default:
            return String(describing: value ?? "")
        }
    }
}
