import { createDocument } from "zod-openapi";
import { writeFileSync } from "fs";
import { z } from "zod";
import { Schema } from "../src/types/schema.js";

const document = createDocument({
  openapi: "3.1.0",
  info: {
    title: "Sleeping Bird API",
    version: "1.0.0",
  },
  paths: {
    "/generate": {
      get: {
        operationId: "generate",
        summary: "Generate tracking suggestions from a user prompt.",
        requestParams: {
          query: z.object({
            prompt: z.string().describe("The user's free-form tracking intent."),
          }),
        },
        responses: {
          "200": {
            description: "Generated suggestions.",
            content: {
              "application/json": {
                schema: z.object({ response: Schema }),
              },
            },
          },
          "400": {
            description: "Missing or invalid prompt.",
            content: {
              "application/json": {
                schema: z.object({ error: z.string() }),
              },
            },
          },
          "500": {
            description: "Generation failed.",
            content: {
              "application/json": {
                schema: z.object({ error: z.string() }),
              },
            },
          },
        },
      },
    },
  },
});

writeFileSync("schema_openapi.json", JSON.stringify(document, null, 2));
console.log("schema_openapi.json generated.");
