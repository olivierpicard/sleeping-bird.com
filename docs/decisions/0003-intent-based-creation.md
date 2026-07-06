# 0003 — Tracker creation: intent-first over type-first

- **Date:** 2026-07-06
- **Status:** Accepted
- **Area:** Tracker Creation Flow (`TrackerIntentView`, `TrackerCreationFlow`)

## Context

From `c08c7f4` the flow forked two ways:

- **Type-first** (`TrackerTypeView`) — user first picks a `TrackerKind`
  (number / duration / choices / …), then names it.
- **Intent-first** (`TrackerIntentView`) — user types what they want to track
  (or taps a suggestion chip); AI resolves the kind and format.

Merged `5ba2c6c` picked intent-first, up to `322b650`.

| Before — type-first (`c08c7f4`) | After — intent-first (`322b650`) |
| --- | --- |
| ![type-first](assets/0003-before-type.png) | ![intent-first](assets/0003-after-intent.png) |

## Decision

Ship **intent-first**, drop **type-first**.

- Asking "what do you want to track?" is more natural than "what shape is it?" —
  users think in goals, not schema types.
- One screen serves both entry points: the "+" button and a tapped dashboard
  suggestion (routed in pre-resolved).
- Removed the type picker and its duration config (`TrackerTypeView`,
  `TrackerDurationConfigView`); added `IntentAiCompletion` to resolve free text.

**Excluded:** the V2 done-reveal animation (`474388e`) stayed on its branch —
merge stopped at `322b650`.

## Consequences

- `TrackerKind` is inferred by AI, not chosen up front.
- Suggestion chips split `emoji` (card) from `chipEmoji` (chip), and each
  suggestion carries ordered best-fit `formats`.

## Reproduce

- **After:** `#Preview("Preselected")` in `TrackerIntentView.swift`.
- **Before:** `TrackerTypeView()` at `c08c7f4` (file deleted on `dev`) — check
  out that commit and render its `#Preview`.
