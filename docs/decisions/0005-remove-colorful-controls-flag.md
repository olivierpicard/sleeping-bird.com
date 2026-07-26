# 0005 — Remove the `colorfulControls` A/B flag; tracker color always wins

- **Date:** 2026-07-16
- **Status:** Accepted
- **Area:** Tint pipeline (`TrackerCreationFlow`, `TrackerIntentView`)
- **Supersedes:** [0004 — The tracker color owns the accent, from resolution
  onward](0004-contrast-corrected-tint.md)

## Context

0004 introduced `TrackerCreationFlow.colorfulControls` as a comparison
switch: `true` tinted controls with the tracker's own (contrast-corrected)
color, `false` kept them on the app accent (indigo). It shipped hardcoded
`true` and stayed that way — the `false` branch was never live, just dead
code checked at three call sites (`controlColor`, the `.formatPicker`
destination, and `TrackerIntentView`'s CTA tint).

Two more spots fell back to accent **by accident**, not through the flag:
the "Continue" button on `TrackerIntentView` before any tracker is
picked/resolved, and the "Try again" retry buttons on the seven per-kind
loading screens — both simply never had a tint set, so iOS used its
default.

## Decision

The comparison is over: tracker color wins, unconditionally.

- Delete `colorfulControls` and its two dead `false`-branch checks in
  `TrackerCreationFlow`. `controlColor` and the `.formatPicker` destination
  now always compute the contrast-corrected tracker color.
- `TrackerIntentView`'s CTA now just tints with `mainColor`, which already
  returns gray in the exact same unresolved/loading guard the old
  `resolvedColor != nil` check used — so the accidental accent fallback
  becomes an intentional gray, matching the screen's already-gray "Try
  again" button in its failure state. The now-redundant `resolvedColor`
  property was removed.
- The seven loading-screen retry buttons keep their accent tint as-is —
  confirmed as the desired look, not something this cleanup touches.

Everything 0004 decided about *why* the correction exists (`ratio: 2.5`,
`readableControlTint`, raw color for card fills vs. corrected color for
text-bearing controls) still stands; only the "compare against indigo"
scaffolding is gone.

## Notes

- No visual change for the app's default behavior — `colorfulControls` was
  already `true`, so this is a code-simplification, not a redesign.
- The raw-color-vs-readable-color duplication described in 0004 is
  unrelated to this cleanup and stays as-is.
