# Repository Guidelines

## Project Structure & Module Organization

`ArperBird/` contains the iOS application. Keep domain logic in `Metric/`, AI integrations in `Ai/`, microphone code in `Audio/` and `Transcriber/`, and SwiftUI screens in `Views/`. The guided tracker flow lives in `TrackerCreation/`; reusable helpers are in `Extensions/`, `Utils/`, and `Support/`. Assets are in `ArperBird/Assets.xcassets`, localized strings in `Localizable.xcstrings`, and StoreKit test configuration in `InAppPurchases.storekit`.

Tests are in `ArperBirdTests/`. Architecture decisions, investigations, and future proposals belong respectively in `docs/decisions/`, `docs/investigations/`, and `docs/proposals/`.

## Build, Test, and Development Commands

Open `ArperBird.xcodeproj` in Xcode and select the shared `ArperBird` scheme to run on a simulator or device. From the repository root:

```sh
xcodebuild test -scheme ArperBird -destination 'platform=iOS Simulator,name=iPhone 16'
bundle exec arkana
```

The first command runs the test target. The second regenerates git-ignored `ArkanaKeys/` after changing local secrets in `Secrets.xcconfig`. Do not commit secrets, generated keys, or local environment files.

## Coding Style & Naming Conventions

Use Swift and SwiftUI conventions: four-space indentation, `PascalCase` for types, `camelCase` for properties and functions, and focused file names matching their primary type. Prefer system font styles and standard SwiftUI controls. Keep persistence changes compatible with the SwiftData migration plan in `Metric/MetricMigrationPlan.swift`; additions inside Codable blobs must remain backward-compatible.

Use `Metric.fakeData` and existing fake AI/transcriber implementations for previews rather than production services. Add or update localized UI text through the string catalog, not hard-coded user-facing copy.

## Testing Guidelines

Tests use both Swift Testing and XCTest. Name suites after the unit under test, such as `MetricAggregatorTests`, and cover pure logic, data shapes, and chart selection changes. Do not run the test suite for ordinary production-code changes; run targeted or full tests only when changing tests, when validation is specifically requested, or when the change directly concerns test behavior. Use Xcode's Test navigator for targeted iteration.

## Commits & Pull Requests

Follow Conventional Commits, for example `feat(tracker-creation): add goal unit validation` or `fix(metric): preserve cumulative bins`. Keep commits scoped. Pull requests should explain the user-visible change, link the relevant issue or decision when applicable, list validation performed, and include simulator screenshots for UI changes. Do not revert unrelated working-tree changes.
