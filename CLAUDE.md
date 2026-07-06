# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ArperBird is an iOS personal data tracker app. Users create a metric — today via a guided, **intent-first Tracker Creation Flow**: the user types (or taps a chip for) *what* they want to track, AI resolves the shape and format, and per-facet AI autocompletions fill in editable defaults (the original one-shot voice/text path still exists in code) — the flow produces a typed schema, and the app renders a card with the appropriate chart type and a matching manual data-entry editor.

> Note: the project was renamed from SleepingBird → ArperBird. Source, tests, scheme, and bundle live under `ArperBird*`; bundle identifiers use the `com.alizetech.arperbird` prefix.

## Building & Running

Open `ArperBird.xcodeproj` in Xcode (no `.xcworkspace`; SPM dependencies). Build and run on a simulator or device (iOS target). The shared scheme is `ArperBird`.

Requires `GoogleService-Info.plist` (present, for Firebase AI) and generated `ArkanaKeys/` (see Secrets below).

### Running Tests

Tests live in `ArperBirdTests/`. Run via Xcode's test navigator or:

```sh
xcodebuild test -scheme ArperBird -destination 'platform=iOS Simulator,name=iPhone 16'
```

The suite uses both Swift Testing (`@Suite`, `#expect`) and XCTest (`XCTestCase`) — both are in the same target. Current coverage focuses on the pure logic: `MetricAggregatorTests` (binning/aggregation) and `MiniChartFactoryTests` (chart selection). Run a single Swift Testing suite/test with `-only-testing:ArperBirdTests/MetricAggregator`.

### Secret Management (Arkana)

API keys are managed with [Arkana](https://github.com/rogerluan/arkana) and stored obfuscated in `ArkanaKeys/` (git-ignored, so must be regenerated locally). Regenerate after changing keys in `Secrets.xcconfig`:

```sh
bundle exec arkana
```

`Secrets.xcconfig` and `.env` are git-ignored. `.arkana.yml` defines one global secret: `DeepgramApiKey`.

### Other keys (currently hardcoded, not in Arkana)

The PostHog project token, RevenueCat API key, and Firebase config live in source (`ArperBirdApp.swift`) / `GoogleService-Info.plist`, not Arkana. Only the Deepgram key is obfuscated.

## Architecture

### Data Model (`Metric` + SwiftData)

`Metric` (`Metric/Metric.swift`) is a SwiftData `@Model` class — the persistent entity for all user metrics. Key fields: `name`, `emoji`, `colorHex`, `config: MetricConfig`, `visual: MetricVisual`, `data: [DataPoint]`. Construct from an LLM result with `Metric(from: schema)` (optionally `data:` for previews/fakes).

`DataPoint` is a `Codable` enum with associated values: `.number(Date, Double)`, `.category(Date, [String])`, `.binary(Date, Bool)`, `.datetime(Date)`, `.duration(Date, TimeInterval)`. Use `metric.append(_:)` to add a point — it validates the type matches `config`.

`Metric` is the only `@Model`. The SwiftData container is built once in `ArperBirdApp` from an **explicit** `Schema(versionedSchema: SchemaV1.self)` + `migrationPlan: MetricMigrationPlan.self` (not `.modelContainer(for:)`), so user data survives App Store updates deterministically rather than via runtime-inferred lightweight migration. To evolve the persisted shape, follow the recipe in `Metric/MetricMigrationPlan.swift`: add a new `SchemaVN` `VersionedSchema`, append it to `MetricMigrationPlan.schemas`, and add a `.lightweight`/`.custom` `MigrationStage`. **Caveat:** `config`, `visual`, and `data` are `Codable` blobs to SwiftData — changes *inside* those types are invisible to the plan, so keep their `Codable` encodings backward-compatible by hand (only add cases/optional fields; never reorder or rename coding keys).

### AI Metric Generation Pipeline (one-shot, voice/text)

Flow: user speaks or types a description → `MetricGenerator` calls `AiMetricSuggestion` → returns a typed `MetricSchema` → a `Metric` is inserted into SwiftData. The pipeline code is live (not stubbed); the old fake path remains commented out in `MetricGenerator`.

> **Entry point caveat:** this one-shot `MetricInputSheet` is currently **not** the active add-metric UI — it's commented out in `ContentView`/`EmptyDashboardView`, superseded by the guided **Tracker Creation Flow** (below). The pipeline classes (`AiSchemaCompletion`, `AiMetricSuggestion`, `MetricGenerator`, the transcribers) are still wired and shared, so keep them working when touching the AI/audio stack.

1. **`Transcriber` protocol** (`Transcriber/Transcriber.swift`) — `hasMicPermission`, `start(onText:)` (closure receives the *full* text so far), `stop()`. Implementations:
   - `DeepgramNova3Transcriber` — the default used by `MetricInputSheet`.
   - `DeepgramFluxTranscriber` — Deepgram v2 WebSocket with real-time turn detection (`EndOfTurn` commits turns; `Update`/`EagerEndOfTurn` are interim).
   - `FakeTranscriber` (`#if DEBUG`) — for previews.
   Audio is supplied by `MicBroker` (see Audio).

2. **`AiSchemaCompletion`** (`Ai/AiSchemaCompletion.swift`) — thin wrapper over the Firebase AI SDK (`FirebaseAILogic`). Opens a `generativeModelSession` on `gemini-3.5-flash` and calls `respond(to:generating:)` with structured output via the `FoundationModels` `@Generable` macro and `ThinkingConfig(thinkingLevel: .medium)`. It takes a `userPrompt`/`systemPrompt` pair plus a `@Generable` type — both the metric-suggestion path and the tracker-creation autocompletions go through it.

3. **`AiMetricSuggestion`** (`Ai/MetricSuggestion/AiMetricSuggestion.swift`) — builds system/user prompts (locale-aware) and calls `AiSchemaCompletion.generate(as: MetricSchema.self)`, returning a single `MetricSchema`.

4. **`MetricGenerator`** (`Metric/MetricGenerator.swift`) — `@Observable`, injected as an environment value. Tracks `pending: [Pending]` (in-flight generations, drives placeholder cards), runs the AI call off `generate(instruction:into:locale:)`, inserts the `Metric`, and emits a `data_schema_generated` PostHog event (with duration/config/chart). Failures emit `captureException`.

5. **`MetricSchema`** (`Ai/MetricSuggestion/MetricSchema.swift`) — the structured-output contract. Key types:
   - `MetricConfig` enum: `number`, `categorySingleChoice`, `categoryMultipleChoice`, `binary`, `datetime`, `duration`
   - `ChartType` enum: `line`, `bar`, `pie`, `calendar`, `dailyGauge`
   - `MetricVisual`: pairs a `ChartType` with an `AggregationConfig`
   - `MetricBehavior`: `.cumulative` (values accumulate, e.g. steps) vs `.snapshot` (independent readings, e.g. weight)
   - All types use `@Generable` / `@Guide` from `FoundationModels` to constrain LLM output

### Tracker Creation Flow (guided, the active add-metric UI)

`ArperBird/TrackerCreation/` — a manual, multi-step alternative to the one-shot voice sheet, and the path actually wired to the "+" button today. The flow is **intent-first** (see [decision 0003](docs/decisions/0003-intent-based-creation.md), which replaced the old type-first picker): the user types what they want to track — or taps a curated **`TrackerSuggestion`** chip — in **`TrackerIntentView`**, `IntentAiCompletion` resolves it to a **`TrackerKind`** (`number`, `duration`, `choices`, `binary`, `goal`, `date` — defined in `TrackerKind.swift`) plus a name/color, then per-facet AI autocompletions fill in editable defaults, ending in a shared celebration "reveal" card. A dashboard badge tap enters the same intent screen pre-resolved. (The old `.name` step / `TrackerNameView` still exists for the legacy seeded path but the intent screen normally skips it.)

- **`TrackerCreationFlow`** (`TrackerCreationFlow.swift`) — coordinator: one push-based `NavigationStack` whose `path: [TrackerCreationStep]` entries are **payload-free**. The root is `TrackerIntentView`; its `onContinue` seeds `model.kind`/`name`/`color` and jumps straight to the kind's first step. Every step reads/writes the shared `model`, which is what lets data survive back-navigation. Transient loading steps swap themselves out of the path in place (`path[top] = .next`) so "back" skips the spinner. The closing `.done` step is hosted by `DoneRevealStep` (a real `View` so model edits re-render) and builds the card via `doneSchema()`/`doneMetric()`.
- **`TrackerCreationModel`** (`TrackerCreationModel.swift`) — `@MainActor @Observable` single source of truth for the whole flow. Owns each sub-flow's state and **memoizes** every AI fetch by name (`loadedName`, `loadedNumberName`, …) so re-showing a screen after a pop is a no-op, never a re-fire. AI calls go through injectable closure seams (`generate`, `generateNumber`, …) defaulting to the real completions, so previews/tests supply data without a network round-trip.
- **AutoCompletion AI layer** (`Ai/AutoCompletion/`) — per-facet `@Generable` completions (`IntentAiCompletion` resolves free text to a kind; `GoalAiCompletion`, `NumberAiCompletion`, `CategoryAiCompletion`, `DurationAiCompletion`, `GranularityAiCompletion`, `EmojiAiCompletion` — the last shared by the binary and date paths). Each wraps `AiSchemaCompletion` with the shared prompts in `AIAutoCompleteInstruction.swift`. `+Fake`/`+Debug` siblings back previews. This is distinct from the `MetricSuggestion` one-shot path — autocompletions return *one facet*, not a whole `MetricSchema`.
- **Tracker color owns the accent** (see [decision 0004](docs/decisions/0004-contrast-corrected-tint.md)) — once the intent screen resolves a prompt, the tracker's palette color takes over every downstream control (CTAs, chips, steppers, nav chrome, reveal chart), not just the card fill. Text-bearing controls use `Color.readableControlTint(in:ratio:)` (`Extensions/Color+Extensions.swift`) to pull the color into a WCAG luminance band per color scheme; `Metric.displayColor(in:)` reuses it so dashboard/charts/editors/detail share the same shade. **Card fills stay raw.** Gated behind `TrackerCreationFlow.colorfulControls` for A/B; `colorScheme` now threads into `MetricViewFactory`/`MetricInputFactory` because the correction is scheme-dependent.
- **Reveal vs. persistence:** the reveal card is seeded with `Metric.fakeData` so its chart looks alive, but the metric that lands on the dashboard (`persistMetric`) starts **empty**. Exception: the **date** and **binary** paths seed a single *real* "today" point instead of faked history — see [decision 0001](docs/decisions/0001-date-reveal-card.md).

### Manual Data Entry (`MetricEditor`)

Once a metric exists, users add points by hand. **`MetricInputFactory`** (`Metric/MetricInputFactory.swift`) maps a `Metric`'s `config` to the right editor under the `MetricEditor` namespace (`Views/MetricEditor/`):
- `MetricEditor.Number` chooses a sub-style by step count via `numberStyle(for:)`: `.stepper` (≤10 steps) → `.slider` (≤100) → `.picker` (≤200) → `.numberInput`. Files prefixed `_` (e.g. `_StepperEditor`) are the concrete implementations.
- `MetricEditor.Category` (`.single`/`.multiple`), `MetricEditor.Binary`, `MetricEditor.Duration` (wheel), `MetricEditor.Datetime` (date picker).
Each editor takes the metric's color and an `onAdd` closure that produces the matching `DataPoint`.

### Rendering Pipeline

6. **`MiniChartFactory`** (`Metric/MiniChartFactory.swift`) — maps a `Metric` to a concrete `MiniChart` (`Views/MiniCharts/`) based on `config` and `visual.chart`. Returns `NoDataMiniChart` when `data` is empty.

7. **`MetricViewFactory`** (`Metric/MetricViewFactory.swift`) — constructs a `MetricView` from a `Metric`. Computes the display value by windowing `data` to the current `TemporalBucket` and applying the `AggregationMethod`.

8. **`MetricView`** (`Views/MetricView/MetricView.swift`) — card UI with emoji header, value display, and a `MiniChart` slot. Takes plain value types — no direct dependency on `Metric`.

9. **`MetricAggregator`** (`Metric/MetricAggregator.swift`) — stateless enum used by `MetricDetailView`:
   - `bins(from:range:method:behavior:)` → `[ChartBin]` for numeric/duration data
   - `categoryEntries(from:range:)` → `[StackedBarChartView.Entry]`
   - Cumulative behavior gap-fills missing buckets with zero.

10. **`MetricDetailView`** (`Views/MetricDetailView.swift`) — full-screen detail. Scrollable chart (bar for numeric, stacked bar for category, `BinaryCalendarView` for binary/datetime) with a 1M / 6M / 1Y `TimeRange` picker and a "Recent Entries" list. Recomputes bins/entries imperatively in `onAppear`/`onChange(of: metric.data.count)` — there is no reactive binding to `metric.data`.

### App Shell, Onboarding & Gating

- **`ArperBirdApp`** — sets up `AppDelegate` (PostHog + Firebase + RevenueCat init), injects `MetricGenerator` and `Store` environments, declares the `Metric` model container, and refreshes purchases on `scenePhase == .active`.
- **`RootView`** — gates on `@AppStorage("hasCompletedOnboarding")`: shows `OnboardingFlow` (StartView → language → mic authorization → guided animation) or `ContentView`. **Free-tier limit**: the app presents `PaywallView` as a non-dismissible sheet once `metrics.count >= 1 && !store.isPremium` — but only after `store.hasLoadedEntitlements`, to avoid a paywall flash for premium users on launch.
- **`ContentView`** — `NavigationStack` showing `EmptyDashboardView` or `DashboardView` (`@Query`-driven cards + pending placeholders). The add-metric "+" now presents `TrackerCreationFlow` as a sheet; the old `MetricInputSheet` presentation is commented out here and in `EmptyDashboardView`.
- **Onboarding tip (TipKit)** — `Tips/AddEntryTip.swift` points the user at a card's "+" button after they create their first metric. `TipKit` is configured in `ArperBirdApp`; the tip is gated by `@Parameter` flags (`hasSettled`, `isPaywallPresented`) set from `RootView`/`MetricView` so it animates in only after the card settles and never over the paywall, and is invalidated once the button is tapped.

### Payments (`Store`)

`Utils/Store.swift` — `@MainActor @Observable` StoreKit 2 wrapper (RevenueCat is configured at launch but entitlement truth comes from StoreKit `Transaction.currentEntitlements`). `Plan` enum holds the product IDs (`com.alizetech.arperbird.premium.{yearly,monthly}`). Exposes `isPremium`, `products`, `purchase`, `restore`, and observes `Transaction.updates`. Every purchase/restore step emits PostHog events (`purchase_started`, `subscription_started`, `restore_completed`, etc.). `InAppPurchases.storekit` is the local StoreKit testing config.

### Identity & Analytics

- **`UniqueIdentityStore`** (`Utils/UniqueIdentity.swift`) — stable per-install UUID stored in the **Keychain** (`kSecAttrAccessibleAfterFirstUnlock`), surviving reinstall. Used as both the PostHog `identify` ID and the RevenueCat `appUserID`, keeping the two aliased.
- **PostHog** — analytics + error tracking on the **EU** instance. Screen views are tracked manually with `View.trackScreen(_:)` (`Extensions/View+TrackScreen.swift`), since SwiftUI has no view-controller lifecycle to auto-capture. Crash symbolication requires dSYM upload — **see `docs/error-tracking.md`** before touching anything PostHog-related (it documents the Release-only build-phase upload and the gotchas).

### Audio

- **`MicBroker`** (`Audio/MicBroker.swift`) — singleton that owns the single `AVAudioEngine` mic tap and fans out 16 kHz mono Int16 PCM buffers to multiple subscribers (transcriber + spectrum analyzer) via `subscribe`/`unsubscribe`. Contains all `AVAudioApplication` permission handling.
- **`SpectrumAnalyzer` / `SpectrumViewModel`** — FFT magnitudes driving the `SpectrumBarView` and `ReactiveMeshBorder` while listening. `LiveSpectrumViewModel` vs `FakeSpectrumViewModel` (previews).
- **`MicUsageTracker`** (`Transcriber/MicUsageTracker.swift`) — caps paid-API dictation cost: sums listening time over a rolling window and **blocks the mic for a cooldown** once a budget is exceeded, persisted in `UserDefaults` so a force-quit can't bypass it. `MetricInputSheet` also hard-caps a single session (`maxListeningDuration`).

### Fakes / Previews

`Ai/MetricSuggestion/FakeMetricSchema.swift` and `Metric/FakeMetric.swift` (`#if DEBUG`) provide `MetricSchema.Fake.*` factories and `Metric.fakeData(for:days:)` synthetic `DataPoint` arrays. `FakeTranscriber` and `FakeSpectrumViewModel` let `MetricInputSheet`/views preview without hitting real APIs, and the `+Fake` AutoCompletion siblings (`Ai/AutoCompletion/TrackerCreation/`) feed the creation-flow previews. Use these in previews instead of the real AI/audio stack.

## Localization

UI strings live in `Localizable.xcstrings` (String Catalog) and are referenced by key (e.g. `metric_input_sheet.placeholder.water`, `store.error.purchase`). Add/edit translations via the `edit-xcstrings` skill rather than hand-editing the JSON. The app passes `locale` through the generation pipeline so the LLM responds in the user's language.

## SwiftUI Conventions

- Always use `Button(action: { … }) { Label("Name", systemImage: "xx") }` for buttons. Apply `.labelStyle(.iconOnly)` when only the icon should be visible.
- Prefer system font styles (`.largeTitle`, `.title`, `.headline`, `.body`, `.caption`, etc.) over custom sizes (`.font(.system(size: N))`). Bypass when a specific size is genuinely needed.
- When adding any UI feature, consider accessibility (Dynamic Type, VoiceOver labels), visibility (contrast, dark mode), and readability (line length, spacing).

## Key Conventions

- `ChartType.calendar` is used for binary and datetime metrics; `ChartType.dailyGauge` requires a `goal` on `NumberConfig`.
- Environment injection: `MetricGenerator` and `Store` are provided at the root and consumed via `@Environment(MetricGenerator.self)` / `@Environment(Store.self)`.
- Fake/preview data comes from `Metric.fakeData(for:days:)` and `MetricSchema.Fake.*`, not inline in views.
- Sub-editor files prefixed with `_` (e.g. `_SliderEditor`) are private implementations of a public `MetricEditor` type — don't use them directly; go through `MetricInputFactory` / `MetricEditor`.
- Commit style is Conventional Commits (see the `commit` skill).
- **Decision log** (`docs/decisions/`) — append-only ADRs (`NNNN-short-slug.md`) capturing reasoning that doesn't survive in code or commits (the decision, the options, why the others lost). Add a new entry to supersede an old one rather than editing history; reference renders go in `assets/`.
