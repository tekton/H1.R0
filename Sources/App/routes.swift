import Vapor

func routes(_ app: Application) throws {
    let browse = BrowseController()
    let images = ImagesController()
    let exifData = ExifDataController()
    let exifParse = ExifParseController()
    let thumbnails = ThumbnailsController()
    let filter = FilterController()
    let searches = SearchesController()

    // Root → browse
    app.get(use: browse.index)

    // Images
    app.get("images", use: images.index)
    app.get("images", "new", use: images.new)
    app.post("images", use: images.create)
    app.get("images", ":id", use: images.show)
    app.get("images", ":id", "edit", use: images.edit)
    app.post("images", ":id", use: images.update)
    app.post("images", ":id", "delete", use: images.delete)
    app.get("images", ":id", "exif", use: images.getExifData)

    // Exif data
    app.get("exif_data", use: exifData.index)
    app.get("exif_data", "new", use: exifData.new)
    app.post("exif_data", use: exifData.create)
    app.get("exif_data", ":id", use: exifData.show)
    app.get("exif_data", ":id", "edit", use: exifData.edit)
    app.post("exif_data", ":id", use: exifData.update)
    app.post("exif_data", ":id", "delete", use: exifData.delete)

    // Admin / processing
    app.get("exif_parse", ":folder", use: exifParse.index)
    app.get("thumbnail", ":folder", use: thumbnails.createFromFolder)

    // Filter
    app.get("filter", ":hash_filter", use: filter.hashFilter)

    // Searches
    app.get("searches", use: searches.index)
    app.get("searches", "new", use: searches.new)
    app.post("searches", use: searches.create)
    app.get("searches", ":id", use: searches.show)
    app.get("searches", ":id", "edit", use: searches.edit)
    app.post("searches", ":id", use: searches.update)
    app.post("searches", ":id", "delete", use: searches.delete)

    // Static assets — serve the Rails app/assets/images directory at /assets/images
    // so existing image and thumbnail paths keep working. Uses a catchall and
    // streams the file from disk; guards against path-traversal escapes.
    app.get("assets", "images", "**") { req -> Response in
        let segments = req.parameters.getCatchall()
        // Reject any traversal attempts before touching the filesystem.
        guard !segments.contains(where: { $0 == ".." || $0.contains("/") }) else {
            throw Abort(.forbidden)
        }
        let base = req.application.directory.workingDirectory + "app/assets/images/"
        let path = base + segments.joined(separator: "/")
        guard FileManager.default.fileExists(atPath: path) else {
            throw Abort(.notFound)
        }
        return req.fileio.streamFile(at: path)
    }
}
