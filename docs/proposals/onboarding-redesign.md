# Onboarding & empty dashboard redesign — two steps into the intent field

- **Date:** 2026-07-07
- **Status:** Proposed — a *for later* path, not implemented
- **Area:** `Views/Onboarding/`, `Views/EmptyDashboardView.swift`,
  `Views/ContentView.swift`, `Views/EmptyDashboard/EmptyDashboardBackground.swift`
- **Relates to:** [decision 0003](../decisions/0003-intent-based-creation.md)
  (intent-first creation), [decision 0004](../decisions/0004-contrast-corrected-tint.md)
  (tint ownership), [dashboard redesign](dashboard-redesign.md)

A UX pass over first-run, sketched during a review session, under one hard
constraint: **the mic is gone** — the new app doesn't use voice input anymore.
Nothing here is committed; it's the direction to reach for when onboarding gets
its next major iteration. If a slice ships, record the actual decision as a new
ADR and link back here.

## Problems with the current flow

1. **Two of four screens exist only to serve the mic.**
   `VoiceLanguageConfigView` and `MicAuthorizationView` configure a feature
   that no longer exists. Dropping the mic doesn't just delete them — it
   breaks the narrative of the other two screens.
2. **The demo rehearses the wrong gesture.** `GuidedAnimation` is
   voice-themed: mic waves + a speech bubble that "speaks" itself out. The
   real creation gesture is now *typing* into `TrackerIntentView`.
3. **Onboarding ends one tap short of the "aha".** It lands on an empty
   dashboard, and the user must find their own way into the creation flow.
   Every screen between install and first tracker costs users.
4. **The empty dashboard has stale copy and competing CTAs.** "Just say it
   out loud" is dead voice copy. Two CTAs fight: suggestion chips *and* a
   bare `+` button — with a hand-drawn arrow spending its charm pointing at
   the weaker of the two. A bare `+` answers nothing about what happens on
   tap.
5. **The Welcome screen's emoji bubbles are decorative.** A first-time user
   learns nothing from ☕💊📈 floating in circles; they don't communicate
   what the app *makes*.

## Flow map

```
BEFORE                                              AFTER

┌───────┐   ┌──────────┐   ┌───────┐   ┌────────┐   ┌─────────┐   ┌──────────────┐
│ Start │──▶│ Language │──▶│  Mic  │──▶│ Guided │   │ Welcome │──▶│  "Type it,   │
└───────┘   └──────────┘   └───────┘   └────────┘   │ (moment)│   │   track it"  │
                 ✂ cut         ✂ cut        │       └─────────┘   └──────┬───────┘
                                            ▼                           │ CTA opens the
                                    Empty dashboard                     ▼ creation flow DIRECTLY
                                    (dead end — user must         ┌──────────────────┐
                                     find "+" themselves)         │ TrackerIntentView │ ← keyboard already up
                                                                  └──────────────────┘
                                                    Empty dashboard = fallback state only
                                                    (user dismissed the sheet), not a step
```

Two screens, then straight into `TrackerCreationFlow(seed: nil)` with the
keyboard raised. The empty dashboard stops being part of onboarding — it's
the safety net behind the sheet. The language screen isn't needed even for
the LLM: the generation pipeline already receives the system `locale`.

## Screen 1 — Welcome (evolved `StartView`)

Keep the bones (entrance choreography, brand gradient, single CTA), but make
the floating bubbles **earn their pixels**: instead of bare emoji circles,
they become miniature live tracker cards — the actual product, floating in.
The user should understand "this app makes these" before reading a word.

```
╭─────────────────────────────────────────────╮
│  9:41                              ●●● 🔋   │
│                                             │
│                 Welcome 👋                  │   fades in first
│                                             │
│              A R P E R   B I R D            │   brand gradient (keep)
│           ═══════════════════════           │
│            Track what matters.              │
│                                             │
│                                             │
│         ┌· · · · · · · · · · · ·┐           │
│    ┌────┴───┐              ┌────┴───┐       │   ← mini CARDS, not bubbles:
│    │ ☕ 3   │   ┌────────┐ │ 💤 7h20│       │     emoji + value + sparkline,
│    │ ▂▄▆▄▇ │   │  🧘 ✓  │ │ ▃▅▄▆▇▆ │       │     built from Metric.fakeData
│    └───┬────┘  │ ██▌░░░ │ └───┬────┘       │     + MiniChartFactory — the
│        ·       └───┬────┘     ·            │     SAME components as the
│        · ┌─────────┴──┐       ·            │     real dashboard
│        · │ 💊 M T W T │ ┌─────┴────┐       │
│        · │   ■ ■ □ ■  │ │ 📖 7/10  │       │   spring in center-out
│        · └────────────┘ │ ━━━━━╸░░ │       │   (keep the stagger),
│        ·                └──────────┘       │   then idle float
│         └· · · · · · · · · · · ·┘          │
│                                             │
│   ╔═════════════════════════════════════╗   │
│   ║        Get started        →         ║   │   ONE CTA, glassProminent,
│   ╚═════════════════════════════════════╝   │   indigo (unchanged)
│                                             │
│      By continuing you agree to our         │
│         Terms and Privacy Policy.           │
│                                             │
╰─────────────────────────────────────────────╯
```

Mini cards with a value + chart *are* the value proposition, and every
component needed already exists (`MiniChart`s + `Metric.fakeData`). Bonus:
these same cards visually "return" in screen 2 and on the creation flow's
reveal step — one continuous visual language from install to first tracker.

## Screen 2 — "Type it, track it" (rebuilt `GuidedAnimation`)

The biggest change. The current loop is *speech bubble + mic waves → card*.
The new mechanic keeps the excellent cycle engine (typing cadence, settle,
morph-to-card, loop) but swaps the metaphor: **a prompt field types itself,
then the card materializes out of it** — which is literally what the real
intent flow does. The demo becomes a rehearsal of the exact gesture the user
performs five seconds later.

```
╭─────────────────────────────────────────────╮
│  ‹ back                                     │
│                                             │
│           Just say what you want            │
│                to track.                    │
│        We'll build the tracker for you.     │
│                                             │
│                                             │
│      ── PHASE A · field types itself ──     │
│                                             │
│   ┌─────────────────────────────────────┐   │
│   │ ✨  Track my coffee intake▎         │   │  ← words appear one by one
│   └─────────────────────────────────────┘   │    (reuse SpeechAnimation
│              ▲ blinking caret               │     word-interval engine),
│                                             │    caret blinks while "typing"
│                                             │
│      ── PHASE B · card morphs in ──         │
│                                             │
│   ┌─────────────────────────────────────┐   │
│   │  ☕  Coffee                   3 cups │   │  ← field's text shrinks into
│   │                                     │   │    the card title; card
│   │      ▂ ▄ ▂ ▆ ▄ ▇ ▅ ▆                │   │    springs up from the
│   │      M T W T F S S                  │   │    field's frame
│   └─────────────────────────────────────┘   │    (matchedGeometryEffect —
│                                             │     replaces slide-up)
│        ● ○ ○ ○ ○   ← cycle dots             │
│                                             │
│   loops: coffee → medication → reading      │
│          goal → mood → gas fill-ups         │
│                                             │
│   ╔═════════════════════════════════════╗   │
│   ║      Create my first tracker        ║   │  ← CTA appears after cycle 1;
│   ╚═════════════════════════════════════╝   │    label promises the NEXT
│                                             │    action, not "Next"
╰─────────────────────────────────────────────╯
```

Key decisions:

- **`MicWavesAnimation` is deleted, not replaced.** The field itself is the
  hero. A pulsing ✨ sparkle in the field while "typing" is enough AI signal.
- **The demo field is styled identically to the real `TrackerIntentView`
  field.** When the CTA fires and the intent screen opens, the user sees
  "oh — it's *that* field, now it's mine." That continuity is the whole
  trick.
- **CTA copy: "Create my first tracker", not "Next"** — it sets the contract
  for what happens on tap. `onComplete` should both set
  `hasCompletedOnboarding` *and* open `TrackerCreationFlow` (a small
  `ContentView`/`RootView` change: completion sets `route = .scratch`).
- The existing timing constants (`wordInterval`, `bubbleSettle`,
  `cardSettle`) and the `texts`/`cards` pairing carry over untouched — only
  the visual shells change. The `texts` need a copy pass though: "Note the
  dates I fill up gas" reads like dictation; typed prompts are terser
  ("Gas fill-up dates").

## Screen 3 — Empty dashboard (fallback state)

Now that onboarding hands off directly to the creation flow, this screen's
only job is: *user closed the sheet without creating anything — invite them
back in.*

```
╭─────────────────────────────────────────────╮
│  9:41                              ●●● 🔋   │
│                                             │
│                                             │
│   ARPER BIRD                                │   keep the tracked caption
│                                             │
│   What do you                               │   keep the two-line headline
│   want to track?          ← gradient        │   ("measure" → "track",
│                                             │    matches TrackerKind lingo)
│   Type it in plain words — we'll            │   NEW copy, replaces
│   build the tracker for you.                │   "Just say it out loud"
│                                             │
│   ┌─────────────────────────────────────┐   │
│   │ ✨  Coffee, sleep, workouts…        │   │   ← THE primary CTA: a fake
│   └─────────────────────────────────────┘   │     input field. Tapping it
│         ▲ same field as onboarding          │     opens TrackerCreationFlow
│           demo & intent screen              │     (scratch) with keyboard up
│                                             │
│   or start from an idea:                    │
│                                             │
│   ( ☕ Coffee )  ( 💤 Sleep )  ( 🚬 Habit ) │   keep BadgesStackView chips
│   ( 💊 Meds )  ( 🏋️ Workouts ) ( 😊 Mood ) │   (seeded route, unchanged)
│                                             │
│                                             │
│              ✕  hand-drawn arrow            │   CUT: arrow + "tap to start"
│              ✕  lone "+" button             │   CUT: bottom "+" (the field
│                                             │   replaces it; toolbar "+"
│                                             │   still exists once the
│                                             │   dashboard has cards)
╰─────────────────────────────────────────────╯
```

**Why the fake field beats the `+`:** a text-field affordance answers *"what
will happen when I tap?"* (I'll type) while a `+` answers nothing. It's the
pattern search-first apps use for their empty states, and — third time now —
it's the *same visual element* the user saw in the demo and will see in the
intent screen. Three sightings of one affordance instead of three different
CTAs (chips, arrow + `+`, intent field).

The hand-drawn arrow and Bradley Hand "tap to start" are charming, but they
exist to rescue an unclear CTA. With a self-explanatory field, they're
solved-problem decoration. If the hand-drawn warmth should live on
somewhere, a small doodle underline under "want to track?" costs nothing and
points at nothing.

## Background — the mesh gradient keeps its personality, intensity does the work

`EmptyDashboardBackground` (a static 3×3 `MeshGradient`, intensity knob,
scheme-aware `tone()`) is solid engineering. The design question is palette
and role — and the answer changed during review, so both takes are recorded.

**First instinct (rejected): shrink to two brand hues.** Indigo anchored in
one corner, one warm counterpoint in the other, everything else neutral —
"the background should whisper the brand, not exhibit the palette."

```
   indigo ░░▒▒ · · · · · neutral
   ░░▒▒ · · · · · · · · · ·
   · · · · neutral · · · · ·
   · · · · · · · · · ▒▒░░
   neutral · · · · ▒▒░░ peach
```

**Why it was rejected:** the background is a big part of the app's
personality, and that personality isn't "five hues" — it's the **warm/cool
tension**: cool indigo/teal up top melting into peach/salmon below, like a
sunrise. That's genuinely distinctive. The two-hue version would be cleaner
but more generic — indigo-gradient-on-neutral is the single most overused
look in AI apps right now. It would trade character for taste, and character
is harder to get back.

**The kept direction:**

1. **Keep the full sunrise palette where personality is the content** —
   Welcome, onboarding, empty dashboard. Those screens have nothing else to
   say; the sunrise *is* the message.
2. **Solve content-competition with intensity, not hue-stripping.** The real
   problem is the background fighting tracker colors on the data dashboard
   (per decision 0004, tracker color owns the accent). The existing `tone()`
   already fixes it: drop the data dashboard from 0.5 to **~0.15–0.2**, where
   the mesh reads as "warm paper" and hue count stops mattering. The
   principle: **full volume in empty/ceremonial moments, low volume behind
   data** — the same background everywhere, breathing with context.

   ```
   Welcome / empty dashboard   onboarding steps      data dashboard
   intensity 1.0               0.3 – 0.5             0.15 – 0.2
   ████ sunrise, loud          ▓▓ present            ░ warm paper
   ```

3. **If any hue goes, it's teal** — the odd one out. The indigo ↔ peach axis
   is the identity; teal is a third voice. Never trim the warmth.
4. **Dark mode: cut saturation, not just brightness.** `0.85 * t` saturation
   on dark reads as a glow behind glass materials; roughly halving it keeps
   the mood without haze, and a near-black base is kinder on OLED.
5. **Accessibility escape hatch:** honor `accessibilityReduceTransparency` /
   increase-contrast by flattening to plain `systemBackground`.
6. **Optional delight, for later:** once the dashboard has trackers, derive
   the two accent stops from the user's dominant tracker colors (heavily
   desaturated through `tone()`). The background becomes faintly *theirs* —
   consistent with the tint-ownership philosophy — at near-zero risk since
   the toning clamps it to whisper level.
7. **Keep it static.** An animated mesh behind scrolling cards is battery
   spend and motion noise for zero information.

## Code impact (summary)

- **Delete:** `MicAuthorizationView`, `MicWavesAnimation`, the `.microphone`
  step, and `VoiceLanguageConfigView` from the flow (the LLM already gets
  the system `locale`; keep `VoiceLanguageOption` only if the transcriber
  stack still references it).
- **`OnboardingFlow`** collapses to `StartView → TypeItDemo`;
  `OnboardingStep` shrinks to one case. No progress bar needed at two steps
  (the commented-out one can go).
- **`StartView`:** swap `emojiBubble` circles for mini tracker cards built
  from `Metric.fakeData` + existing `MiniChart`s; entrance choreography
  unchanged.
- **`GuidedAnimation` → `TypeItDemo`:** keep the cycle `Task`, timings, and
  `texts`/`cards` pairing; replace the `SpeechAnimation` bubble with a typing
  prompt field, replace slide-up with a `matchedGeometryEffect` field → card
  morph; CTA becomes "Create my first tracker".
- **`ContentView`/`RootView`:** onboarding completion sets `route = .scratch`
  so the creation flow opens immediately; `EmptyDashboardView` becomes purely
  the dismissed-sheet fallback.
- **`EmptyDashboardView`:** new subcopy, fake-input primary CTA calling
  `onAddMetric(nil)`, chips stay, arrow + bottom `+` removed.
- **`EmptyDashboardBackground`:** data-dashboard intensity 0.5 → ~0.15–0.2;
  dark-mode saturation halved; reduce-transparency fallback.

## Open trade-off

Opening the creation sheet straight out of onboarding is assertive — a user
who dismisses it lands on the empty dashboard having never "seen" it first.
The bet is that the redesigned empty state is self-explanatory enough. The
softer variant: land on the empty dashboard with the fake field doing a
one-time attention pulse.
