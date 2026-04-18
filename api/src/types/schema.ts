import { z } from "zod";

const DataType = z.enum([
  "categorySingle",
  "categoryMultiple",
  "duration",
  "dateTime",
  "binary",
  "number",
]);

const BoundedNumberConfig = z.object({
  min: z
    .number()
    .describe("Lower bound. E.g., 0 for weight, 1 for a 1-10 scale."),
  max: z
    .number()
    .describe("Upper bound. E.g., 500 daily carbs, 10 for pain levels."),
  granularity: z
    .number()
    .describe(
      "Increment step. E.g., 1 for counts, 0.1 for precise weight, 0.25 for quarter increments, 0.5, 0.01, 2, 5, 10, ...",
    ),
  unit: z
    .string()
    .optional()
    .describe("Display unit. E.g., 'kg', 'steps', 'kcal', 'cup'."),
  goal: z
    .number()
    .optional()
    .describe("Optional target value. E.g., 2000 calories."),
});

const CategoryConfig = z.object({
  labels: z
    .array(z.string())
    .min(2)
    .max(15)
    .describe(
      "List of options. E.g., ['Great', 'Good', 'Meh', 'Bad'] or ['Chest Day', 'Legs', 'Cardio'].",
    ),
});

const DurationConfig = z.object({
  granularity: z
    .enum(["ms", "s", "m", "h"])
    .describe(
      "The smallest unit of input allowed. 's' allows seconds, 'm' limits to minutes/hours.",
    ),
  max: z
    .number()
    .describe(
      "Expected max duration in SECONDS. If > 3600, UI shows H/M/S. If < 3600, UI shows M/S. E.g., 7200 for a 2h workout.",
    ),
});

const BinaryConfig = z.object({
  trueLabel: z.string().describe("E.g., 'Did it', 'Yes', 'Took Meds'."),
  falseLabel: z.string().describe("E.g., 'Missed', 'No', 'Sober'."),
});

const Config = z.discriminatedUnion("dataType", [
  z.object({
    dataType: z.literal("number"),
    boundedNumber: BoundedNumberConfig,
  }),
  z.object({
    dataType: z.literal("categorySingle"),
    category: CategoryConfig,
  }),
  z.object({
    dataType: z.literal("categoryMultiple"),
    category: CategoryConfig,
  }),
  z.object({
    dataType: z.literal("duration"),
    duration: DurationConfig,
  }),
  z.object({
    dataType: z.literal("binary"),
    binary: BinaryConfig,
  }),
  z.object({
    dataType: z.literal("dateTime"),
  }),
]);

export const Suggestion = z.object({
  metricName: z
    .string()
    .describe(
      "Concise, title-cased name. E.g., 'Daily Hydration', 'Deep Sleep Duration', 'Anxiety Level'.",
    ),
  dataType: DataType.describe("The primitive type of data being recorded."),
  fitProbability: z
    .number()
    .min(0)
    .max(1)
    .describe(
      "Confidence score [0.0 to 1.0]. Use 1.0 only if the user's intent is unambiguous (e.g., 'Track steps'). Use values < 1.0 to offer multiple perspectives for vague intents (e.g., 'Track my runs' could be 0.8 for duration and 0.2 for number of laps).",
    ),
  config: Config,
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
