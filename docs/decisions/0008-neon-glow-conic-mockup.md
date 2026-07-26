# 0008 — Neon glow border: a conic-gradient mockup, stopped at MVP depth

- **Date:** 2026-07-10
- **Status:** Accepted — `AiGlowBorderMockup2` is a UI-test mockup; the head/tail
  upgrade below is documented, not built.
- **Area:** `Views/AiGlowBorderMockup2.swift`
- **Relates to:** [decision 0007](0007-empty-dashboard-intent-glow-handoff.md)
  (the shipping `AIGlowBorder`, a perimeter-walk built for the same field)

## Context

We want the creation field to look like it **emits light** — the reference is a
neon capsule on black: a thin white-hot filament, a saturated colored edge, a
big soft bloom, and hues that **circulate** around the shape.

- Reference, plain: [`assets/0008-reference-neon-capsule.png`](assets/0008-reference-neon-capsule.png)
- Reference, with the detail this decision turns on:
  [`assets/0008-reference-head-tail.png`](assets/0008-reference-head-tail.png)

The load-bearing observation in the second image: the **beige/orange region is
brighter than the rest** — it reads as the *head* of the light (hotter core,
bigger bloom) and the colors behind it fall off like a *tail*. That asymmetry is
a big part of why the reference feels alive rather than like a decal.

0007 already shipped `AIGlowBorder` for this field via a **perimeter walk** (a
`Canvas` drops spectrum blobs around the rounded-rect by arc length). This entry
covers a **second, independent** exploration — a mockup with a live control
panel — deliberately kept as a separate file so the two can be compared.

## Decision

### Render with one spun conic `AngularGradient` — the approach 0007 rejected

0007 rejected a conic gradient because it distributes color **by angle from the
center**, so on a wide, short field most of the range lands on the long
top/bottom edges and the short ends go to a single hue — a "hole" in an
*evenly-lit* ring. That rejection was correct **for 0007's goal** (uniform
coverage). It is exactly wrong here: the reference *has* that distribution —
long multi-hue edges, single-hue ends — so the conic's "flaw" reproduces the
target for free. Same technique, opposite verdict, because the goal differs.

The render is a stack, bottom to top: blurred copies of the same stroked ring
(the bloom), drawn twice — masked *outside* the shape and clipped *inside* it,
so the two leak directions are independently tunable — then the sharp edge line,
all additively blended (`.plusLighter`) on a dark surface and flattened with
`.drawingGroup()`. Circulation is just the gradient's `angle` advancing with the
clock.

Two bugs found and fixed here, worth recording because both had non-obvious
causes (and 0007 half-predicted the first):

- **Single-color freeze.** Feeding the raw clock in as the angle (~10¹⁰ degrees)
  overflows GPU `Float` precision: the conic sweep collapses to its first stop
  (uniform color) *and* the per-frame delta rounds to zero (no motion). Fix:
  wrap the phase to one lap before converting to degrees — 360° ≡ 0°, so the
  wrap is invisible.
- **Gray inward spill.** Blurring the whole ring *into* a short capsule overlaps
  the top edge's hues with the bottom's; near-complementary light (pink+cyan,
  orange+blue) sums to gray. Fix: re-saturate the inward layer *after* the blur
  (`inwardSaturation`).

### The control panel is the deliverable, kept flat and global

The mockup's value is a tuning surface. Knobs, all on `AiGlowBorderMockup2Style`:

- `stops` — colors **and** their spread (stop *locations* are the spread; a
  palette picker demonstrates it).
- `period` — seconds per lap (`≤ 0` freezes).
- `edgeIntensity` (0–2) — dims the edge below 1; above 1 a white stroke fades in
  over the color so the line burns white in the middle (overdriven-tube look).
- `outwardLeak` / `inwardLeak` — how *far* each side spreads (blur radius).
- `outwardIntensity` / `inwardIntensity` — how *bright* each side is (split from
  spread on request, so brightness and reach are separate axes).
- `inwardSaturation` — the gray-fix above, exposed.

### Stop here for the MVP

The head/tail asymmetry is **not** built. Reproducing it faithfully needs
per-color control of the *bloom*, which the single-gradient model **cannot**
express — the blur is applied to the whole ring at once, so there is no way to
say "bloom the orange sector more." That is a rendering-model change, and this is
an MVP. The current mockup gets the emissive look, the circulation, and the
directional leaks; that is enough.

## Alternatives (for when it's worth going beyond)

Two ways to get the brighter beige head, both deferred:

- **Comet-head overlay (cheap, recommended).** Keep the single-gradient render;
  add one bright hotspot layer riding the ring at a chosen loop position, with
  its own intensity/spread, plus a tail-fade dimming the gradient behind it.
  ~2–3 sliders, and it matches the reference — which has **one** head, not six
  individually-tuned colors. Doesn't preclude the fuller version later.
- **Per-color light sources (truthful, expensive).** Change the model from "one
  gradient ring" to **N colored lights on the ring**, each with its own angular
  position, width, core brightness, bloom spread, and bloom intensity; global
  sliders become multipliers over the per-color values. More physically honest (a
  neon sign *is* separate tubes) and it subsumes head/tail naturally. Costs:
  layer count becomes `colors × passes` (measure before production), and the
  panel needs per-color expandable rows instead of a flat list. This is the right
  investment only if the goal is a playground to *discover* looks, not to land
  this one effect.

## Reproduce

Open the `#Preview("Playground")` in `AiGlowBorderMockup2.swift` and run it live
in Xcode's canvas (static snapshots don't show the circulation). Drive the six
sliders + palette picker. To sanity-check the two fixes: set Period low and
confirm the ring stays multi-color and moving (precision fix); push In intensity
to full and confirm the interior wash stays colorful, not gray (saturation fix).

## See also

- [Investigation — the glowing creation field snaps on keyboard dismiss](../investigations/glow-border-keyboard-snap.md) — an open follow-up bug in the shipped glow.
