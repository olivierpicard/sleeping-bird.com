# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SleepingBird is an iOS personal data tracker app. Users describe a metric they want to track (via text or voice dictation), an LLM interprets it, and the app renders a card with the appropriate chart type and configuration.

## Building & Running

Open `SleepingBird.xcodeproj` in Xcode. Build and run on a simulator or device (iOS target).

### Running Tests

Tests live in `SleepingBirdTests/`. Run via Xcode's test navigator or:

```sh
xcodebuild test -scheme SleepingBird -destination 'platform=iOS Simulator,name=iPhone 16'
```

The suite uses both Swift Testing (`@Suite`, `#expect`) and XCTest (`XCTestCase`) — both are in the same target.

### Secret Management (Arkana)

API keys are managed with [Arkana](https://github.com/rogerluan/arkana) and stored obfuscated in `ArkanaKeys/`. To regenerate after changing keys in `Secrets.xcconfig`:

```sh
bundle exec arkana
```

`Secrets.xcconfig` is git-ignored. The `.arkana.yml` config defines one global secret: `DeepgramApiKey`.

## Architecture

### Data Model (`Metric` + SwiftData)

`Metric` (`Metric/Metric.swift`) is a SwiftData `@Model` class — the persistent entity for all user metrics. Key fields: `name`, `emoji`, `colorHex`, `config: MetricConfig`, `visual: MetricVisual`, `data: [DataPoint]`.

`DataPoint` is a `Codable` enum with associated values: `.number(Date, Double)`, `.category(Date, [String])`, `.binary(Date, Bool)`, `.datetime(Date)`, `.duration(Date, TimeInterval)`. Use `metric.append(_:)` to add a point — it validates the type matches `config`.

### AI Metric Generation Pipeline

The core flow: user speaks or types a description → `MetricGenerator` calls `AiMetricSuggestion` → returns a typed `MetricSchema` → a `Metric` is inserted into SwiftData.

1. **`Transcriber` protocol** (`Transcriber/Transcriber.swift`) — defines `start(onText:)` / `stop()`. Two concrete implementations:
   - `DeepgramFluxTranscriber` — uses Deepgram v2 WebSocket with real-time turn detection (`EndOfTurn` events commit turns; `Update`/`EagerEndOfTurn` are interim).
   - `DeepgramNova3Transcriber` — alternative Deepgram model.

2. **`AiSchemaCompletion`** (`Ai/AiSchemaCompletion.swift`) — thin wrapper over Firebase AI SDK (`FirebaseAILogic`), calls Gemini (`gemini-3-flash-preview`) with structured output via the `FoundationModels` `@Generable` macro.

3. **`AiMetricSuggestion`** (`Ai/AiMetricSuggestion.swift`) — constructs the system/user prompts and calls `AiSchemaCompletion.generate(as: MetricSchema.self)`, returning a single `MetricSchema`.

4. **`MetricGenerator`** (`Metric/MetricGenerator.swift`) — `@Observable` class injected as an environment value. Manages `pending: [Pending]` (each representing an in-flight generation), calls `AiMetricSuggestion`, and inserts the resulting `Metric` into the SwiftData context. Currently stubbed with fake data while the real AI call is commented out.

5. **`MetricSchema`** (`Ai/MetricSchema.swift`) — the structured output contract. Key types:
   - `MetricConfig` enum: `number`, `categorySingleChoice`, `categoryMultipleChoice`, `binary`, `datetime`, `duration`
   - `ChartType` enum: `line`, `bar`, `pie`, `calendar`, `dailyGauge`
   - `MetricVisual`: pairs a `ChartType` with an `AggregationConfig`
   - `MetricBehavior`: `.cumulative` (values accumulate, e.g. steps) vs `.snapshot` (independent readings, e.g. weight)
   - All types use `@Generable` / `@Guide` from `FoundationModels` to constrain LLM output

### Rendering Pipeline

6. **`MiniChartFactory`** (`Metric/MiniChartFactory.swift`) — maps a `Metric` to a concrete `MiniChart` implementation based on `config` and `visual.chart`. Returns `NoDataMiniChart` when `data` is empty.

7. **`MetricViewFactory`** (`Metric/MetricViewFactory.swift`) — constructs a `MetricView` from a `Metric`. Computes the display value by windowing `data` to the current `TemporalBucket` and applying the `AggregationMethod`.

8. **`MetricView`** (`Views/MetricView.swift`) — card UI with emoji header, value display, and a `MiniChart` slot (height 100 pt). Takes plain value types — it has no direct dependency on `Metric`.

9. **`MetricAggregator`** (`Metric/MetricAggregator.swift`) — stateless enum with two methods used by `MetricDetailView`:
   - `bins(from:range:method:behavior:)` → `[ChartBin]` for numeric/duration data
   - `categoryEntries(from:range:)` → `[StackedBarChartView.Entry]`
   - Cumulative behavior gap-fills missing buckets with zero.

10. **`MetricDetailView`** (`Views/MetricDetailView.swift`) — full-screen detail. Shows a scrollable chart (bar for numeric, stacked bar for category, `BinaryCalendarView` for binary/datetime) with a 1M / 6M / 1Y `TimeRange` picker and a "Recent Entries" list.

### Views

- `ContentView` — entry point; button to open `MetricInputSheet` as a sheet, toggle between Flux/Nova3 transcribers, nav link to `Dashboard`.
- `MetricInputSheet` — sheet where user types or dictates a metric description, then taps Send to trigger `MetricGenerator.generate(instruction:into:)`.
- `DashboardView` — `@Query`-driven list of `MetricView` cards, plus placeholder cards for pending generations.

### Fakes

`FakeMetricSchema.swift` (`#if DEBUG`) adds `MetricSchema.Fake` with static factory methods for every config type, and `Metric.fakeData(for:days:)` generates synthetic `DataPoint` arrays. Use these in SwiftUI previews instead of hitting the real AI.

## SwiftUI Conventions

- Always use `Button(action: { … }) { Label("Name", systemImage: "xx") }` for buttons. Apply `.labelStyle(.iconOnly)` when only the icon should be visible.
- Prefer system font styles (`.largeTitle`, `.title`, `.headline`, `.body`, `.caption`, etc.) over custom sizes (`.font(.system(size: N))`). Bypass when a specific size is genuinely needed.
- When adding any UI feature, consider accessibility (Dynamic Type, VoiceOver labels), visibility (contrast, dark mode), and readability (line length, spacing).

## Key Conventions

- `ChartType.calendar` is used for binary and datetime metrics; `ChartType.dailyGauge` requires a `goal` on `NumberConfig`.
- `MetricGenerator` is injected as `.environment(MetricGenerator())` at the root and consumed with `@Environment(MetricGenerator.self)`.
- Fake/preview data is generated by `Metric.fakeData(for:days:)` and `MetricSchema.Fake.*`, not inline in views.
- `MetricDetailView` recomputes bins/entries imperatively in `onAppear` and `onChange` — there is no reactive binding to `metric.data`; any new addition triggers recompute via `onChange(of: metric.data.count)`.
