# 0007 — Empty dashboard → intent: auto-typing handoff with an AI glow beat

- **Date:** 2026-07-09
- **Status:** Accepted — `AIGlowBorder` shipped; the auto-type + resolved-sheet
  handoff is designed here, implementation pending.
- **Area:** `Views/EmptyDashboard/EmptyDashboardView.swift`,
  `TrackerCreation/TrackerIntentView.swift`, `TrackerCreation/TrackerCreationFlow.swift`,
  `Views/AIGlowBorder.swift`
- **Relates to:** [decision 0006](0006-empty-dashboard-redesign.md) (empty
  dashboard: launcher field + example chips), [decision 0003](0003-intent-based-creation.md)
  (intent-first creation)

## Context

After 0006 the empty dashboard presents a launcher **field CTA** and **example
chips**; both open `TrackerCreationFlow` → `TrackerIntentView`. That intent
screen showed its *own* field, its *own* (freshly re-sampled) chips, a preview
card, and format pills — all at once. Three problems, all from one screen doing
two jobs at the same time:

1. **Duplicated chips.** A user who tapped the dashboard field already declined
   the chips; the sheet re-showing a *different random sample* read as the app
   changing its mind.
2. **Unrelated chips once text existed.** Chips are capture aids; with the field
   already filled (typed or badge-seeded), they answered a question already
   answered, with options that felt random next to the text.
3. **Badge entry felt lost.** A one-tap decision dropped the user into a full
   workshop (field + chips + card + pills + CTA) with no hierarchy and no obvious
   next step.

Root cause: the intent screen fused **capture** ("what do you want to track?")
and **review** ("how do you want to log it?") into one surface.

## Decision

Split the two jobs and make each entry point land in the state its intent
implies. The field teaches; the review screen confirms.

### Part 1 · Keep the "how to log it" screen; it is the review surface

The card + format pills is already good — simple, intuitive, and it answers
*how to log it*. It is kept as-is. Its one precondition is that the **what** is
already known, which is what the rest of this decision supplies.

### Part 2 · The field's real job is to teach, not to collect text

The intent field's value is teaching that **plain words are enough** — that is
the perceived-risk reducer (per 0006, first contact is where this lands hardest).
So the *what* must be produced somewhere the lesson is delivered, not bypassed.

### Part 3 · The empty-dashboard field becomes the typing stage

A badge tap does **not** jump straight to review. Instead it drives the
dashboard's **own** field: the phrase auto-types into it, word by word, with
**non-uniform cadence** (fixed-interval typing is precisely what read as
robotic). The badge path becomes the typed path with the app as the typist, so a
badge user gets the same lesson — *you just type plain words* — without typing.

Rejected alternatives for the badge path:

- **Badge → straight to review.** Skips the field lesson, leaving perceived risk
  high for later free-text use.
- **Badge → sheet with a prefilled field + "Continue".** A typing screen with
  the typing already done — empty and weird; the one action that gives the screen
  purpose has been removed.

### Part 4 · A fake "AI glow" loading beat motivates the sheet

The remaining seam was mechanical: typing finishes, *then* the sheet opens — a
hard cut that reads as a pre-recorded clip. Fix: after typing, an
Apple-Intelligence-style spectrum glow **circulates around the CTA field**
(~0.8–1.0 s), then blooms and the sheet opens **already resolved**. This turns
an unmotivated cut into a causal chain the mind accepts — *typed → thinking →
result*.

Crucially, the field's glow **replaces** the sheet's internal spinner: the
"thinking" happens in the field, and the sheet is the answer, so there is no
double loading. The same glow is reused on the real typed path, where the AI
call is genuine — so the badge sequence stops feeling like a special-case
playback and is just the normal loading, self-started.

Rejected: the fuller choreography (the tapped chip flying into the field,
matched-geometry shared field across dashboard → sheet, multi-track breathing).
Correct in spirit but too complex; the auto-type + glow beat carries the same
"connected" feeling far more cheaply.

### Part 5 · The glow is a forked `AIGlowBorder`

`Views/AIGlowBorder.swift` is a new, standalone component — a **fork of
`ReactiveMeshBorder`'s technique** (soft colored blobs walked around a
rounded-rect perimeter, then blurred into light), but driven by *time* instead
of a mic, so the color circulates rather than reacting to audio.

**Rejected first attempt — a spun conic `AngularGradient`.** A conic gradient
was tried (spin the filled layer so every hue sweeps around). It fails on a
**wide, short field**: a conic distributes color by *angle from the center*, so
almost its entire range lands on the long top/bottom edges and the short sides
go dark — a "hole" in the ring. Evening the palette's brightness did not fix it,
because the cause is geometric, not tonal. (Also noted: rotating the gradient's
*start angle* clamps every pixel to the first stop, since the time-derived angle
is huge — the layer must be spun with `.rotationEffect`, not the angle.)

**Adopted — a perimeter walk by arc length.** A `Canvas` walks the field's
rounded-rect perimeter (`perimeterPoint`, forked from `ReactiveMeshBorder`) and
drops a spectrum-tinted blob at each step. Arc-length placement gives **every
side equal coverage regardless of aspect ratio** — no hole — and sliding the
color offset per frame (`rgb(at: p + offset)`) makes the hues **travel around**
the border. Details:

- the spectrum is stored as **brightness-matched RGB triples** (darker
  blues/violets lifted, bright gold tamed) and interpolated at a *continuous*
  loop position, so the ring is smooth and doesn't throb bright/dark as it spins;
- blobs paint with the canvas's **default (overwrite) blend** so the ring is one
  even solid color; the additive glow happens **once**, layer-vs-field, so
  overlaps don't blow out — **`.plusLighter` on dark** (hues build into light,
  matching the reference), **normal on light** (adding would wash the pastel rim
  to white);
- **outward bloom, not inward:** the layer renders into a `GeometryReader`-sized
  frame **padded by a margin** on every side and is slid back, because `Canvas`
  clips to its own bounds and would otherwise cut the outward glow. Blobs are
  pushed *outward* off the edge (`outwardBias`) with a small blur so the light
  sits **outside** the field and the interior/text stays clean — brighter and
  crisper than a centered, heavily-blurred rim;
- **shine:** a smaller, whiter core drawn over each blob (`coreShine` lifts the
  tint toward white) gives the neon-outline highlight;
- a gentle opacity **breath** keeps it alive; **Reduce Motion** freezes the
  circulation. The breath is a `breathes` toggle — its size-pulse (an opacity
  swing reads as size through the blur) can be switched off for a dead-steady
  ring.

Attached via `.aiGlowBorder(isActive:…)`, transient — so the field's resting
design (per 0006) is unchanged. The tuning dials (`blobRadius`, `blurRadius`,
`outwardBias`, `coreShine`, `breathes`) default to a soft look; a brighter /
crisper / more-outward tune is under evaluation via the compare preview.
Verified in light and dark via the `#Preview`s.

## Consequences

- The intent screen no longer needs to re-show chips for the dashboard entry
  paths; chips survive only where the dashboard didn't already show them (e.g. a
  later non-empty-dashboard "+", if any).
- The dashboard field gains transient behavior — auto-typing + glow — while its
  static layout stays frozen.
- `AIGlowBorder` is a new reusable component; the loading duration is simply how
  long the glow breathes, not a comet lap to time.
- **Pending:** wiring the sequence (badge tap → auto-type into the dashboard
  field → `isActive` glow beat → present the intent screen pre-resolved on the
  review state). Record follow-through here or supersede if the design shifts.

## Reproduce

- **The glow:** the `#Preview`s in `AIGlowBorder.swift` — "around a field"
  (default look), "field, no breath" (steady vs. breathing), "bright vs current"
  (the brighter/crisper/outward tune next to the default, forced dark so the
  shine reads), and "full frame". Render in Light and Dark to see the
  circulation and the light/dark blend split. Note: static snapshots don't show
  the circulation — run them live in Xcode's canvas.

## See also

- [Investigation — the glowing creation field snaps on keyboard dismiss](../investigations/glow-border-keyboard-snap.md) — an open follow-up bug in the shipped glow.
