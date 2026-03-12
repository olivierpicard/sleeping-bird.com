# Requirements — User-Draft-Driven Reply Generation

## Problem Statement

Currently the extension auto-prefetches 5 AI replies based solely on the tweet text when the user navigates to a tweet. The new behavior should let the user type their own brief comment/opinion/draft in the modal, then generate 5 expanded/riffed variations using the tweet as context and high temperature for diversity. Copy-to-clipboard on card click stays the same.

## Requirements

1. Remove background prefetch — no API call on URL change
2. Modal opens with a text input area + "Generate" button instead of loading spinner
3. User types their draft, clicks Generate, then sees a loading state followed by 5 response cards
4. AI prompt uses the user's draft as the main direction and the original tweet as context
5. Temperature stays high (1.8) for diversity across the 5 cards
6. Clicking a card copies to clipboard and closes modal (unchanged)
