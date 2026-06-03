import Foundation
import Crypto

/// Produces a stable MD5 hash for a set of {tag, value} filter pairs.
///
/// The Rails original hashed the YAML of an array of hashes. This rewrite
/// canonicalizes the pairs as sorted JSON (matching `Search.encode`) and hashes
/// the UTF-8 bytes with MD5, so the hash is internally consistent across the
/// browse, filter, and search code paths.
enum FilterHash {
    /// MD5 of the canonical JSON encoding of the given tag/value pairs.
    static func hash(_ tagValues: [TagValue]) -> String {
        let canonical = Search.encode(tagValues)
        let digest = Insecure.MD5.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Convenience for a single tag/value pair (the browse list case).
    static func hash(tag: String, value: String) -> String {
        hash([TagValue(tag: tag, value: value)])
    }
}
