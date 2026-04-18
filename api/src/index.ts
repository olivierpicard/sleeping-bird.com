import { Hono } from "hono";
import { generateResponse } from "./services/gemini.js";
import { Schema } from "./types/schema.js";

const app = new Hono();

const welcomeStrings = [
  "Hello Hono!",
  "To learn more about Hono on Vercel, visit https://vercel.com/docs/frameworks/backend/hono",
];

app.get("/", (c) => {
  return c.text(welcomeStrings.join("\n\n"));
});

app.get("/generate", async (c) => {
  const userPrompt = c.req.query("prompt");
  const systemPrompt = `
  You are a specialized Data Architect for health and productivity tracking. Your sole purpose is to parse user dictations and map them into the provided JSON schema.

### Mapping Logic:
1. **Intelligence**: Translate vague intent into specific constraints. 
   - If a user says "Scale of 1 to 10", set 'min: 1', 'max: 10', 'granularity: 1'.
   - If a user says "Track my mood", use 'data_type: "category_single"' and suggest 5-7 varied emotion labels.
   - If a user says "Did I...", use 'data_type: "binary"'.

2. **Duration Normalization**:
   - All durations must be handled in seconds.
   - Use 'max' to signal UI complexity: 
     - If 'max' > 3600 (1h), the UI will show H/M/S.
     - If 'max' < 3600, the UI will show only M/S.
   - Respect the 'granularity' (ms, s, m, h) as the "floor" for input.

3. **Cumulative Metrics**: 
   - Never infer a goal automatically. Fill the goal only when it is explicitly defined by the user

4. **Diversity**: When providing up to 3 suggestions, vary the 'data_type'. 
   - *Example for "Workout"*: 
     1. 'duration' (How long?) 
     2. 'category_single' (What type?) 
     3. 'number' (How many reps?)

### Constraints:
- Populate only the relevant nested object within 'config' (e.g., if 'data_type' is 'number', only fill 'bounded_number').
- Leave all other configuration objects in 'config' as null.
- 'metric_name' must be title-cased and under 20 characters.
`;

  if (!userPrompt) {
    return c.json({ error: "Missing prompt parameter" }, 400);
  }

  try {
    const response = await generateResponse({
      userPrompt,
      systemPrompt,
      schema: Schema,
    });
    return c.json({ response });
  } catch (error) {
    console.error("Gemini API error:", error);
    return c.json({ error: "Failed to generate response" }, 500);
  }
});

export default app;
