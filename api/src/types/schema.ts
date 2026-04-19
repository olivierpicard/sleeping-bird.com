import "zod-openapi";
import { z } from "zod";

const SuggestionBase = z.object({
  metricName: z
    .string()
    .describe(
      "Concise, title-cased name. E.g., 'Daily Hydration', 'Deep Sleep Duration', 'Anxiety Level'.",
    )
    .meta({ example: "Daily Hydration" }),
  fitProbability: z
    .number()
    .min(0)
    .max(1)
    .describe(
      "Confidence score [0.0 to 1.0]. Use 1.0 only if the user's intent is unambiguous (e.g., 'Track steps'). Use values < 1.0 to offer multiple perspectives for vague intents (e.g., 'Track my runs' could be 0.8 for duration and 0.2 for number of laps).",
    )
    .meta({ example: 0.9 }),
});

const NumberSuggestion = SuggestionBase.extend({
  dataType: z.literal("number"),
  min: z
    .number()
    .describe("Lower bound. E.g., 0 for weight, 1 for a 1-10 scale.")
    .meta({ example: 0 }),
  max: z
    .number()
    .describe("Upper bound. E.g., 500 daily carbs, 10 for pain levels.")
    .meta({ example: 500 }),
  granularity: z
    .number()
    .describe(
      "Increment step. E.g., 1 for counts, 0.1 for precise weight, 0.25 for quarter increments, 0.5, 0.01, 2, 5, 10, ...",
    )
    .meta({ example: 1 }),
  unit: z
    .string()
    .optional()
    .describe("Display unit. E.g., 'kg', 'steps', 'kcal', 'cup'.")
    .meta({ example: "kcal" }),
  goal: z
    .number()
    .optional()
    .describe("Optional target value. E.g., 2000 calories.")
    .meta({ example: 2000 }),
})
  .describe(
    "Track a numeric value within a defined range. E.g., weight, calories, pain level, steps.",
  )
  .meta({ id: "NumberSuggestion" });

const CategorySingleSuggestion = SuggestionBase.extend({
  dataType: z.literal("categorySingle"),
  labels: z
    .array(z.string())
    .min(2)
    .max(15)
    .describe("List of mutually exclusive options. E.g., ['Great', 'Good', 'Meh', 'Bad'].")
    .meta({ example: ["Great", "Good", "Meh", "Bad"] }),
})
  .describe("Track a single choice from a fixed list. E.g., mood, workout type.")
  .meta({ id: "CategorySingleSuggestion" });

const CategoryMultipleSuggestion = SuggestionBase.extend({
  dataType: z.literal("categoryMultiple"),
  labels: z
    .array(z.string())
    .min(2)
    .max(15)
    .describe("List of options, multiple can be selected. E.g., ['Chest', 'Legs', 'Cardio'].")
    .meta({ example: ["Chest", "Legs", "Cardio"] }),
})
  .describe("Track multiple choices from a fixed list. E.g., symptoms, workout muscles.")
  .meta({ id: "CategoryMultipleSuggestion" });

const DurationSuggestion = SuggestionBase.extend({
  dataType: z.literal("duration"),
  granularity: z
    .enum(["ms", "s", "m", "h"])
    .describe(
      "The smallest unit of input allowed. 's' allows seconds, 'm' limits to minutes/hours.",
    )
    .meta({ example: "m" }),
  max: z
    .number()
    .describe(
      "Expected max duration in SECONDS. If > 3600, UI shows H/M/S. If < 3600, UI shows M/S. E.g., 7200 for a 2h workout.",
    )
    .meta({ example: 7200 }),
})
  .describe("Track an elapsed time. E.g., workout duration, sleep, meditation session.")
  .meta({ id: "DurationSuggestion" });

const BinarySuggestion = SuggestionBase.extend({
  dataType: z.literal("binary"),
  trueLabel: z
    .string()
    .describe("E.g., 'Did it', 'Yes', 'Took Meds'.")
    .meta({ example: "Took Meds" }),
  falseLabel: z
    .string()
    .describe("E.g., 'Missed', 'No', 'Sober'.")
    .meta({ example: "Missed" }),
})
  .describe("Track a yes/no habit or event. E.g., took medication, exercised today.")
  .meta({ id: "BinarySuggestion" });

const DateTimeSuggestion = SuggestionBase.extend({
  dataType: z.literal("dateTime"),
})
  .describe("Track a point in time. E.g., bedtime, appointment.")
  .meta({ id: "DateTimeSuggestion" });

export const Suggestion = z
  .discriminatedUnion("dataType", [
    NumberSuggestion,
    CategorySingleSuggestion,
    CategoryMultipleSuggestion,
    DurationSuggestion,
    BinarySuggestion,
    DateTimeSuggestion,
  ])
  .meta({
    id: "Suggestion",
    discriminator: {
      propertyName: "dataType",
      mapping: {
        number: "#/components/schemas/NumberSuggestion",
        categorySingle: "#/components/schemas/CategorySingleSuggestion",
        categoryMultiple: "#/components/schemas/CategoryMultipleSuggestion",
        duration: "#/components/schemas/DurationSuggestion",
        binary: "#/components/schemas/BinarySuggestion",
        dateTime: "#/components/schemas/DateTimeSuggestion",
      },
    },
  });

export const Schema = z.object({
  suggestions: z
    .array(Suggestion)
    .min(1)
    .max(3)
    .describe(
      "A list of 1 to 3 tracking configurations based on the user's intent.",
    ),
});

export type Suggestion = z.infer<typeof Suggestion>;
export type Schema = z.infer<typeof Schema>;
