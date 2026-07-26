//
//  CategoryLimits.swift
//  ArperBird
//

/// Shared bounds on how many choices a `choices` tracker can have — used by
/// both AI-generated category schemas and the manual category-label UI so
/// the limit stays in sync across all three surfaces.
enum CategoryLimits {
    static let min = 2
    static let max = 7
}
