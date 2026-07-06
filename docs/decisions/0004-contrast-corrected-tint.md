# 0004 — The tracker color owns the accent, from resolution onward

- **Date:** 2026-07-06
- **Status:** Accepted
- **Area:** Tint pipeline (`Color.readableControlTint`, `Metric.displayColor`,
  `TrackerCreationFlow`, dashboard / editors / detail)

## Context

Each tracker has a palette color, but it was only ever a **card fill**. Every
control around it — CTAs, chips, keypads, steppers, nav chrome, the reveal chart —
stayed on the app accent (indigo), so the color never owned its flow.

## Decision

Two roles for color, kept separate:

- **Indigo = app chrome** — the neutral system accent, for anything that isn't yet
  a specific tracker.
- **Tracker color = the tracker's identity** — owns its accent everywhere it appears.

The rule: **identity begins at resolution, not at completion.** The moment the
intent screen resolves a prompt into a `kind` + color (`onContinue`), that *is* the
tracker — so its color takes over every downstream step, spinner, reveal, and the
saved card. Before resolution the intent screen stays neutral (gray card, indigo
CTA); that's correct.

This is cheap because the flow already holds `color`, so one tint at the root
cascades:

```swift
@State private var color: Color = .accent   // indigo until resolution
// onContinue: color = intentColor            // identity begins here
NavigationStack(path: $path) { … }.tint(controlColor)  // flows to every step + nav chrome
```

> **Legacy gap:** the old type-first `init` path leaves `color` at `.accent`, so
> "indigo default" still leaks there. Thread the per-kind color through it too and
> indigo would only ever appear pre-resolution.

### The shade must be corrected

The palette is tuned for card fills, so the raw color breaks on controls: bright
members (yellow, teal) can't carry **white glyphs**, and in dark mode the tint also
draws as **text on near-black**, where dark members are unreadable.

So text-bearing controls use `Color.readableControlTint(in:ratio:)`, pulling the
color into a WCAG luminance band per scheme — caps luminance so white text holds,
floors it (dark mode) so it reads as text. `Metric.displayColor(in:)` reuses it so
the dashboard, charts, editors, and detail share the same shade. **Card fills stay
raw** — only text-bearing controls get corrected.

**Why `ratio: 2.5`** (below AA's 3:1 for UI components): the tint carries
headline-weight labels, not body text, and we'd rather keep the hue recognizable
than hit the bar. Raise it if the tint ever has to carry small text.

## Alternatives

- **Keep controls on indigo** — the prior state; identity never leaves the card.
  Kept as the `false` branch of the flag.
- **Tint with the raw color** — breaks white-on-color and dark-mode text.

## Notes

- Gated behind `TrackerCreationFlow.colorfulControls` (`true`) for A/B; delete the
  flag once it wins.
- `colorScheme` now threads into `MetricViewFactory` / `MetricInputFactory` —
  correction is scheme-dependent, so it resolves where the scheme is known.
- The `readableControlTint` doc comment still says "3:1" — stale after the drop to
  2.5; the signature wins.

## Reproduce

Flip `colorfulControls` and render the intent / reveal previews. Watch the accent
switch from indigo to the tracker color at "Continue"; check a bright and a dark
color against the reveal CTA in both light and dark mode.
