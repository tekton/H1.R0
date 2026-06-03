import Vapor
import Fluent
import FluentPostgresDriver
import Leaf
import Queues
import QueuesRedisDriver

public func configure(_ app: Application) async throws {
    // MARK: Database (PostgreSQL)
    // Read DATABASE_URL from the environment, defaulting to a local Postgres.
    if let databaseURL = Environment.get("DATABASE_URL") {
        var tlsConfig: PostgresConnection.Configuration.TLS = .disable
        // Allow opting into TLS for managed databases.
        if databaseURL.contains("sslmode=require") {
            var nio = TLSConfiguration.makeClientConfiguration()
            nio.certificateVerification = .none
            tlsConfig = .require(try .init(configuration: nio))
        }
        var postgresConfig = try SQLPostgresConfiguration(url: databaseURL)
        postgresConfig.coreConfiguration.tls = tlsConfig
        app.databases.use(.postgres(configuration: postgresConfig), as: .psql)
    } else {
        app.databases.use(
            .postgres(
                configuration: .init(
                    hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                    port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432,
                    username: Environment.get("DATABASE_USERNAME") ?? "postgres",
                    password: Environment.get("DATABASE_PASSWORD") ?? "postgres",
                    database: Environment.get("DATABASE_NAME") ?? "h1r0_development",
                    tls: .disable
                )
            ),
            as: .psql
        )
    }

    // MARK: Migrations
    app.migrations.add(CreateImage())
    app.migrations.add(CreateExifDatum())
    app.migrations.add(CreateSearch())
    // The schema already exists on the live DB; migrations are idempotent-friendly
    // for fresh environments. Auto-migrate only when explicitly requested.
    if Environment.get("AUTO_MIGRATE") == "true" {
        try await app.autoMigrate()
    }

    // MARK: Leaf templating
    app.views.use(.leaf)

    // MARK: Redis-backed Queues
    let redisURL = Environment.get("REDIS_URL") ?? "redis://localhost:6379"
    try app.queues.use(.redis(url: redisURL))

    // Register background jobs.
    app.queues.add(ExifJob())
    app.queues.add(ThumbnailJob())

    // Run jobs in-process during development so a separate worker is optional.
    if Environment.get("IN_PROCESS_JOBS") == "true" {
        try app.queues.startInProcessJobs(on: .default)
    }

    // MARK: Routes
    // Static asset serving (the Rails app/assets/images directory) is handled by
    // a dedicated route in routes.swift using req.fileio.streamFile.
    try routes(app)
}
