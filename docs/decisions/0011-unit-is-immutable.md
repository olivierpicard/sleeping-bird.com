# 0011 — The unit is fixed at creation, not editable afterwards

- **Date:** 2026-07-28
- **Status:** Accepted
- **Area:** Metric edit sheet (`Views/MetricDetails/MetricEditSheet.swift`)

## Context

`MetricEditSheet` let the user rewrite a number metric's `unit` — a free-text
field next to the name. Changing it rewrites the *label* on the metric and
nothing else: every `DataPoint` already stored keeps its raw `Double`.

So a heart-rate tracker holding a year of `bpm` readings, renamed to `%`, still
charts the same numbers under a unit they no longer mean. To make the edit
truthful the app would have to convert the whole history — and it can't, because
there is no conversion table (`bpm → %` isn't even a conversion) and no way to
know whether the user meant "I mislabelled this" or "I want different units from
here on".

## Options

**Option A — drop the field; the unit is set at creation only** *(chosen)*

**Option B — keep the field, convert history on save** *(rejected)*

Needs a unit ontology (kg↔lb, km↔mi, …) plus a fallback for pairs that don't
convert.

**Option C — keep the field, warn that past entries aren't converted**
*(rejected)*

## Decision

Ship **A**.

**A wrong unit is better fixed by making a new tracker.** Mislabelling happens at
creation and is caught immediately, when there's no history worth keeping. The
field earns its place only for the rare late correction, and it pays for that by
letting every user silently corrupt the meaning of their own archive.

**B is real work with a small payoff.** A conversion layer is a feature in its
own right (unit families, factors, rounding, non-convertible pairs); it doesn't
belong behind an inline text field in an edit sheet.

**C was rejected because a warning doesn't make the data right.** It moves the
responsibility to the user for a decision they have no good way to evaluate, and
the outcome is still a chart whose old points lie.

## Consequences

- The sheet edits **name, emoji, colour** only. `save()` no longer touches
  `metric.config`, so editing a metric can't reshape it.
- The unit still appears in the sheet's header card, as read-only context under
  the name (and nothing shows when there is none).
- `metric_edit_sheet.field.unit`, `.placeholder.unit` and `.no_unit` are dropped
  from the string catalog.
- Only creation writes `NumberConfig.unit` (via the AI autocompletions). If a
  late correction is ever needed, it should arrive as a deliberate "change unit"
  flow that states what happens to history — not as a text field.
