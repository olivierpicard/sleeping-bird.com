# Investigation — the glowing creation field snaps on keyboard dismiss

**Status:** open (root cause identified, no working fix yet)
**Area:** `ArperBird/Views/EmptyDashboard/TrackerInputFieldCTA.swift`, `ArperBird/Views/GlowBorder.swift`
**Related:** [ADR 0007](../decisions/0007-empty-dashboard-intent-glow-handoff.md), [ADR 0008](../decisions/0008-neon-glow-conic-mockup.md)

---

## Symptom

`TrackerInputFieldCTA` is the "Track …" field on the empty dashboard. It carries
the neon glow (`.glowBorder(…)`) and is welded into one geometry with
`.geometryGroup()`. When it's focused the keyboard raises it; when the keyboard
goes away the field travels back down.

The **descent is inconsistent**, depending on *how* the keyboard is dismissed:

| Dismissal | What happens | Wanted? |
|---|---|---|
| Keyboard **submit** (return/go key) | Field slides down **smoothly** | ✅ yes |
| **Tap elsewhere** to dismiss | Field **snaps** abruptly to the bottom | ❌ no |

The two should look identical. Only the tap-to-dismiss path jumps.

The first clue: **commenting out the `.glowBorder(…)` modifier removes the
snap.** So the glow — not the field layout on its own — is implicated.

## When it happens

- Only on the empty-dashboard creation field, because that's the one that both
  (a) wears the glow and (b) moves under keyboard avoidance.
- Only while the glow is **actively rendering** during the keyboard's downward
  animation (see the evidence table — this is the crux).
- The submit path *looks* fine, but note the caveat below: that may be because
  the glow is held active a different way, not because that path is immune.

### Why submit differs from tap

In `TrackerInputFieldCTA` the glow's visibility is:

```swift
.glowBorder(…, isActive: isLoading || isFocused)
```

- **Submit** sets `isLoading = true` *before* the keyboard leaves, so `isActive`
  stays `true` across the dismissal (held up by `isLoading`).
- **Tap elsewhere** only flips `isFocused → false` with `isLoading == false`, so
  `isActive` goes `true → false` exactly as the keyboard animates down.

So the two paths differ in whether the glow is active/animating during the
descent. That framed the whole investigation.

## Root cause

The bug is driven by the **`TimelineView(.animation)`** that used to power the
color circulation in both glow layers (`GlowBorder` and `GlowWash`).

A `TimelineView(.animation)` re-evaluates its subtree — **layout included** —
on **every display frame**. SwiftUI keyboard avoidance moves the field by
animating a safe-area inset; that animation is a Core Animation interpolation
from the old position to the new one. But each `TimelineView` tick re-runs
layout and resolves the field to its **final** (resting) position, which
effectively *completes* the in-flight keyboard animation on that frame. The
result: instead of interpolating down over ~0.3 s, the field teleports.

When the glow is **not** ticking (paused / removed / never shown), there's no
per-frame relayout, so the keyboard animation interpolates normally and the
field slides.

### Evidence

Each row is a single-variable experiment run against the original
`TimelineView`-based code:

| Change | Timeline ticking during descent? | Snap? |
|---|---|---|
| Original (`isActive: isLoading \|\| isFocused`) | yes (was on while focused) | **yes** |
| `isActive: true` (always on) | yes | **yes** |
| `isActive: isLoading` (never on while typing) | no | no |
| Force `paused: false` in the `TimelineView` | yes | **yes** |
| Replace `TimelineView` with a **static angle** (glow still drawn) | no | no |
| Remove `.drawingGroup()` only | yes | **yes** |
| Remove the `.colorEffect` dither shader only | yes | **yes** |
| Remove `.geometryGroup()` on the field only | yes | **yes** |
| Comment out **both** `GlowBorder` + `GlowWash` bodies | no | no |
| Comment out **either one** alone | yes | **yes** |

Reading of the table:

- The **pause state of the `TimelineView` predicts the snap perfectly.** Ticking
  ⇒ snap; not ticking ⇒ smooth.
- It is **not** the `drawingGroup`, the dither shader, or the `geometryGroup` —
  removing each individually still snaps.
- It is **not** the `isActive` *transition* — the static-angle test still toggled
  `isActive` and faded opacity, yet was smooth.
- Both glow layers cause it **independently** (either one alone snaps), and the
  one thing they share is the `TimelineView`. That's what pinned the cause.

## Attempted fix (did NOT work)

Commit-in-progress in `GlowBorder.swift`. The idea: keep the exact look (colors
travelling around the border) but drive the circulation **without** a per-frame
layout re-evaluation, so it can't complete the keyboard animation.

What was changed:

1. **New `GlowCirculation` driver** replacing `TimelineView`. It spins a `spin`
   angle `0° → 360°` with an implicit, repeating animation:

   ```swift
   withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
       spin = 360
   }
   ```

   Rationale: a `rotationEffect` animated through the normal animation system
   updates **presentation transforms only** — it should not re-run the host's
   layout, unlike `TimelineView`.

2. **`ring` / `gradientPaint` restructure.** Instead of stroking the shape with a
   time-varying `AngularGradient`, we now fill an oversized rectangle with a
   *fixed-angle* gradient, apply `.rotationEffect(spin)`, and **mask it to the
   stroked outline**. Rotating the *paint* (not the ring shape) keeps the colors
   travelling around a fixed outline. Same treatment for `GlowWash` (`mask(shape)`).

3. Removed the now-unused time helpers (`circulationAngle`,
   `glowCirculationAngle`).

**Result: the field still snaps on tap-to-dismiss.** The fix compiles and
(visually) circulates, but does not resolve the bug.

### Why it likely failed (hypotheses, unverified)

The presentation-layer reasoning was apparently too optimistic. Leading
suspicions, in order:

- **Any continuously-running animation in the field's subtree completes the
  keyboard-avoidance animation**, not just `TimelineView`. A `repeatForever`
  implicit animation still produces a per-frame stream of transactions; each one
  may re-resolve/settle the concurrent layout animation the same way the
  `TimelineView` ticks did. If so, the mechanism was mis-attributed to
  "TimelineView re-runs layout" when the real trigger is "a concurrent
  ever-running animation in the same transaction scope."
- **`.geometryGroup()` couples the ever-animating overlay to the field**, so the
  group's geometry is re-settled every animation frame regardless of *which*
  animation primitive drives it — and the removal test above only removed
  `geometryGroup` while the `TimelineView` was still present, so we never tested
  "no `geometryGroup` **and** a presentation-only animation" together.
- The `rotationEffect` animation may still be forcing `body`/layout
  re-evaluation more than assumed (e.g. via the `@State spin` change), rather
  than being a pure render-server interpolation.

## Open questions / next directions

Not yet tried; ordered roughly by expected signal:

1. **Isolate the trigger.** Drop a bare `Rectangle().rotationEffect(…)` with a
   `repeatForever` animation next to the field (no glow) and see if the field
   still snaps. If yes → *any* concurrent forever-animation fights keyboard
   avoidance, and the fix must remove the concurrency, not change the primitive.
2. **Decouple the glow from the keyboard-avoided layout.** Render the glow so it
   does not participate in the field's safe-area-driven movement (e.g. a sibling
   overlay positioned from the field's frame, or `.ignoresSafeArea(.keyboard)`
   on the glow with the field's motion mirrored some other way).
3. **Own the vertical motion.** Disable keyboard avoidance for the field and move
   it ourselves with a single explicit animation keyed to keyboard
   show/hide — so there's no *system* layout animation for the glow to complete.
4. **Freeze circulation during the transition window only.** Hold the spin for
   ~0.35 s around a focus change, then resume. Earlier reasoning suggested this
   might not help (the original already paused on `isActive → false` and still
   snapped), but it's worth an empirical check now that the mechanism is clearer.

## Reproduction

1. Launch to the empty dashboard.
2. Tap the "Track …" field to focus it (keyboard rises, glow lights up).
3. Tap empty space (not the return key) to dismiss.
4. Observe the field jump to the bottom instead of sliding.

Compare against dismissing via the keyboard's go/return key, which slides.
