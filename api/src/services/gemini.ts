import { GoogleGenAI, ThinkingLevel } from "@google/genai";
import { Schema } from "../types/schema.js";
import * as z from "zod";
const genai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
});

export async function generateResponse(p: {
  userPrompt: string;
  systemPrompt: string;
  schema: z.ZodObject;
}): Promise<{}> {
  const response = await genai.models.generateContent({
    model: "gemini-3-flash-preview",
    contents: p.userPrompt,
    config: {
      systemInstruction: p.systemPrompt,
      thinkingConfig: {
        thinkingLevel: ThinkingLevel.MINIMAL,
      },
      responseMimeType: "application/json",
      responseJsonSchema: z.toJSONSchema(p.schema),
    },
  });

  if (!response.text)
    throw "The generated response is empty. It is not allowed";
  const result = JSON.parse(response.text);

  return result;
}
