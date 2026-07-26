//
//  MetricMigrationPlan.swift
//  ArperBird
//
//  Explicit SwiftData schema versioning so that data survives App Store
//  updates. Every change to the persisted `Metric` shape must be expressed
//  as a new `VersionedSchema` plus a `MigrationStage`, instead of relying on
//  implicit automatic lightweight migration.
//
//  How to evolve the schema:
//  1. Add a new `SchemaVN` enum capturing the new shape (snapshot the model
//     if the change is structural enough that V(N-1) can no longer describe
//     it; otherwise keep referencing `Metric.self`).
//  2. Append it to `MetricMigrationPlan.schemas`.
//  3. Add a `.lightweight` (additive/optional/defaulted changes) or
//     `.custom` (everything else) `MigrationStage` from V(N-1) to VN.
//
//  NOTE: `config`, `visual`, and `data` are `Codable` blobs from SwiftData's
//  point of view, so changes *inside* those types are invisible to this plan.
//  Keep their `Codable` representations backward-compatible by hand (only add
//  cases / optional fields; never reorder or rename coding keys).
//

import Foundation
import SwiftData

/// The shape of `Metric` as first pinned for explicit versioning. This matches
/// the schema already shipping in the store, so introducing it requires no
/// migration of existing data.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Metric.self]
    }
}

/// The ordered history of schema versions and the migrations between them.
/// Passed to `ModelContainer` so SwiftData migrates deterministically rather
/// than inferring at runtime.
enum MetricMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — V1 is the baseline. Add a stage here when a
        // future SchemaV2 is introduced.
        []
    }
}
