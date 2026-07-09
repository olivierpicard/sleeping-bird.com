# 0006 — Empty dashboard: minimal header, example chips, an animated launcher field

- **Date:** 2026-07-08 → 2026-07-09
- **Status:** Accepted (MVP scope)
- **Area:** `Views/EmptyDashboard/EmptyDashboardMockup.swift`,
  `Views/EmptyDashboardView.swift`, `TrackerCreation/TrackerIntentView.swift`
- **Relates to:** [onboarding-redesign proposal](../proposals/onboarding-redesign.md)
  (Screen 3), [decision 0003](0003-intent-based-creation.md) (intent-first
  creation)

## Context

This ADR records the full redesign of the empty dashboard — the first screen a
user meets with no trackers yet — per the proposal's Screen 3. The starting
point placed the headline and chips up top, with the real CTA a bare floating
`+` at the bottom, reached only via a hand-drawn "tap to start" arrow:

| Before — chips up top, arrow to a floating `+` |
| --- |
| <img src="assets/0006-old-empty-dashboard.png" width="280"> |

The redesign's premise: **promote a tappable input field to the primary CTA**,
killing the arrow and the bare `+`. That single move reframed the whole layout
and opened three questions, each resolved below:

1. **The header** above the headline — what does the screen show?
2. **The bottom part** — do the chips read as examples of what to type, or as a
   separate path?
3. **The field itself** — static placeholder, or animated? And what happens on
   tap?

All three were explored in `EmptyDashboardMockup` — a design-only harness where
the field and chips present the real `TrackerIntentView` sheet but nothing else
is wired.

## Part 1 · The header — minimal, no decoration

Two layout families were tried first, then five header treatments for the winner.

### Layout family

| A — Ghost card | B — Minimal |
| --- | --- |
| ![A](assets/0006-a-ghost-card.png) | ![B](assets/0006-b-minimal.png) |

- **A (ghost card)** reads unambiguously as an empty state, but the header *is*
  the intent screen's preview card — it feels **duplicated and low-effort**,
  and even shrunk (an intermediate "small ghost card" variant) it still echoed
  that card. Too many stacked titles also buried the field's CTA.
- **B (minimal)** breathes, and the field clearly reads as the CTA — but the
  generic 📈 glyph is **decorative and teaches nothing** (the same critique the
  proposal makes of the Welcome screen's emoji bubbles), and it feels *less*
  like an empty state.

B's weaknesses are **additive** (layer an empty-state cue back on); A's are
**structural** (the duplication is baked into the concept). So B won the base,
and the search moved to a better header than the 📈 glyph.

### Header candidates (on B's layout)

| C1 — Empty slot | C2 — Baseline | C3 — Mascot |
| --- | --- | --- |
| ![C1](assets/0006-c1-empty-slot.png) | ![C2](assets/0006-c2-baseline.png) | ![C3](assets/0006-c3-mascot.png) |

| C4 — Skeleton | C5 — Constellation |
| --- | --- |
| ![C4](assets/0006-c4-skeleton.png) | ![C5](assets/0006-c5-constellation.png) |

- **C1 · Empty slot** — clean, but the dashed frame + `+` reads as *tappable*,
  competing with the real field CTA below. Rejected: false affordance.
- **C2 · Baseline** — an axis + dotted zero-line. Just reads **weird** at this
  size; too abstract/technical to land as "empty".
- **C3 · Mascot** — the Arper Bird, perched. **The favourite idea** — the only
  header with brand personality (recovers the hand-drawn warmth being cut). But
  it needs a **real mascot illustration**, and the MVP doesn't have one; the
  `bird.fill` SF Symbol is a placeholder, not shippable identity.
- **C4 · Skeleton** — faint list rows. Good idiom, but reads as a **loading**
  state and sits **out of place / unbalanced** on this layout. Rejected.
- **C5 · Constellation** — loose dots implying a trend-to-be. **Loved**, but
  only worth it *animated*: dots connecting/disconnecting into a semi-connected
  graph, and on connection each dot blooming into an emoji bubble. Too complex
  for now. Kept as a "for later" delight, not MVP.

**Decision — ship B (minimal) with no header decoration.** None of the
candidates is both cheap *and* clearly better than empty space: C1 fights the
CTA, C2/C4 misread, and the two that excite (C3 mascot, C5 constellation) each
need real investment (an illustration; an animation) the MVP can't fund yet. B
without a header keeps the field as the unmistakable CTA and ships today. The
background carries the personality (per the proposal's "full volume in
empty/ceremonial moments").

## Part 2 · The bottom part — label + tight proximity

With the header settled (none), the question became **how the chips relate to
the field** — examples of what to type, or a separate path?
`EmptyDashboardMockup`'s `ChipLink` explored four ties:

| A — examples | B1 — OR divider |
| --- | --- |
| ![A](assets/0006-chip-a-examples.png) | ![B1](assets/0006-chip-b1-or.png) |

| B2 — OR, isolated | C — proximity |
| --- | --- |
| ![B2](assets/0006-chip-b2-or-isolated.png) | ![C](assets/0006-chip-c-proximity.png) |

- **A · examples** — a `Try one:` label directly above the chips, tight to the
  field, no separating spacer.
- **B1 · OR divider** — a `—— OR ——` rule between the field and the chips.
- **B2 · OR divider, stronger isolation** — same rule, more whitespace/visual
  separation around the chip group.
- **C · grouped / proximity** — chips tucked immediately under the field, no
  label and no divider; binding is pure proximity.

**B1 and B2 dropped.** The `OR` divider frames the chips as an *alternative*
path with equal weight to typing, when the intent is the opposite: typing is the
CTA and the chips are just examples of it. The rule pushes the chips away from
the field — they read as a separate feature, "less related." B2 makes this worse
by isolating the group further. Both fight the goal.

**A and C both had a piece.** C wins on proximity (chips clearly belong to the
field) but leans entirely on layout inference and feels a touch clogged. A adds
the one thing C lacks — a label that *names* the relationship ("these are things
you could type") — communicating the tie even when a user isn't reading the
layout carefully.

**Decision — the A+C hybrid.** Keep A's `Try one:` label (it names the chips as
examples) with C's tightened spacing: the field → label → chips collapse into
one tight sub-block bound by proximity, no divider and no container box. This
gets both the explicit framing *and* the visual grouping without the `OR` wall.
| Final decision |
| --- |
| <img src="assets/0006-chip-chosen-hybrid.png" width="380"> |

## Part 3 · The text field — animate it, then hand off to the intent screen

### 3.1 · Animate the launcher field

The field CTA was still **static** — a single frozen placeholder. Should it
rotate through examples the way `TrackerIntentView`'s field does?

**Decision — yes.** It now rotates through the intent screen's "Track …"
examples (kept in sync via the shared `TrackerIntentView.examplePrompts`),
keeping its own `sparkles` glyph, with the same `.push(from: .bottom)`
transition and a `reduceMotion` → `.opacity` fallback. The animation does two
jobs at once:

- **It teaches.** A static "Coffee, sleep, workouts…" shows *breadth* but not
  *phrasing*; rotating full natural-language examples ("how many coffees I
  drink", "if I stretched today") teaches the lesson that you *describe a
  behavior in plain words*, not pick a category. On the empty dashboard this is
  first contact, so the lesson matters most here.
- **It draws focus.** Motion is the strongest pull on this otherwise-calm
  screen, so it concentrates attention on the field — the one thing we want
  tapped — and makes the screen read as **polished and alive** rather than a
  dead form.

### 3.2 · Hand off to a focused intent field

The empty-dashboard field is honest about being a **launcher**, not a real
input.

**Decision — a tap presents `TrackerIntentView` with `autofocusField: true`,**
which raises the keyboard and focuses the field (a ~0.35s beat lets the present
transition settle first, or the focus is dropped). Auto-focusing deliberately
**freezes the intent screen's own rotation**, because two nearly identical
animating fields back-to-back read as **redundant and unpolished** — the user
feels stuck in a *loop*, as if the tap did nothing and the UI didn't understand
them. Auto-focusing instead:

- removes the redundant animation (no motion competing with a fresh keyboard),
- **anchors focus** — the user lands already typing, one tap saved,
- **draws the link between the two pages** — the dashboard field's promise
  ("type here") is fulfilled the instant the sheet opens, so the two screens
  read as one continuous action rather than two separate steps.

The chips opt *out* of autofocus (`autofocusField: false`): a chip stands in for
a pre-resolved pick, so no keyboard is needed.

## Shipped

The empty dashboard is: sunrise background at full intensity → centered gradient
headline → subcopy → an **animated launcher field** (rotating intent examples,
`sparkles` glyph) → a `Try one:` label → example chips, with the
field/label/chips collapsed into one tight proximity-bound sub-block. No header
artifact above the headline. Tapping the field presents `TrackerIntentView`
auto-focused; tapping a chip presents it pre-resolved without autofocus.

## Consequences

- `EmptyDashboardView` follows B: no top artifact; animated field CTA + labelled
  chips over `EmptyDashboardBackground` at full intensity.
- `TrackerIntentView` gains an `autofocusField` flag and freezes its own field
  rotation when launched focused; `examplePrompts` is the shared source for both
  screens' rotations.
- The `EmptyDashboardMockup` harness is collapsed to a single `#Preview`,
  `Label + tight proximity` (the chosen bottom-part layout). It stays as a
  `#if DEBUG` design reference.
- **Revisit triggers:** (1) a real mascot illustration exists → reopen **C3**;
  (2) appetite for a signature animation → build **C5** (animated constellation
  → emoji bubbles). Record either as a new ADR superseding this one.

## Reproduce

`EmptyDashboardMockup.swift` carries only the chosen `Label + tight proximity`
preview. The rejected directions — the ghost-card layout, headers C1–C5, and the
chip-tie alternatives (OR dividers, plain proximity) — live only in the render
assets above; the harness no longer carries their variants.
