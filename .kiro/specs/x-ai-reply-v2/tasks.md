# Tasks - X.com AI Reply V2

- [x] Task 1: Remove the Insert Reply button and copy to clipboard on response selection
  - Remove the "Insert Reply" button from the modal footer
  - Remove the `ai-reply-modal-footer` section from the modal HTML and its CSS styles
  - When a response card is clicked, copy that reply to the clipboard and close the modal
  - Show brief "✓ Copied to clipboard!" feedback before closing
  - Visible result: modal no longer has a footer with an Insert button; clicking a response copies it to clipboard

- [x] Task 2: Start generating the AI response on post click (URL change detection)
  - Add a URL change listener (using `popstate`, `pushState`/`replaceState` interception, or polling) to detect when the user navigates to a tweet detail page (e.g. `/status/` URL pattern)
  - When a tweet detail page is detected (including on page load/refresh), immediately extract the main tweet text and start calling the Grok API in the background (before the user clicks the ✨ icon)
  - Cache the generated responses keyed by tweet URL so they are ready instantly when the modal opens
  - Clear stale cache entries when navigating away from a tweet
  - Visible result: opening the modal on a tweet detail page shows responses almost instantly instead of waiting for the API, even after refreshing the page

- [x] Task 2.5: Refactor modal to only reflect cache state (no generation on modal open)
  - Remove all API call logic from the `openModal()` function
  - Modal should ONLY read from the cache when opened
  - If cache has a response for the current tweet URL: display it immediately
  - If cache is empty/not set for the current tweet URL: show loading state with message "Generating response..."
  - Remove the try/catch API call block from `openModal()`
  - Clean up any code that triggers API calls when the modal opens
  - The modal becomes a pure "view" of the cache state - all generation happens in the background via URL change detection
  - Visible result: modal opens instantly showing either cached response or loading state; no API calls are triggered by opening the modal

- [x] Task 3: Generate 5 different responses per tweet
  - Update the Grok API call to request 5 completions (use `n: 5` parameter or make 5 parallel requests with varied temperature)
  - Store all 5 responses in the cache alongside the tweet URL
  - Visible result: API now returns 5 distinct reply options per tweet. Concole.log the responses

- [x] Task 4: Display the 5 responses as selectable cards in the modal
  - Replace the single preview text area with a scrollable list of 5 response cards
  - Each card shows the reply text with a subtle border and hover highlight
  - Clicking a card selects it visually (highlight border in blue) and inserts the reply into the composer, then closes the modal
  - If responses are still loading, show a spinner; as each response arrives, append its card progressively
  - Update modal CSS for the card layout (card container, individual card styles, selected state, hover state)
  - Visible result: modal displays 5 clickable response cards; clicking one inserts it and dismisses the modal

- [x] Task 5: Fix infinite loading screen when modal opens before cache is ready
  - Add a cache update listener/observer mechanism that notifies the modal when responses become available
  - When the modal is in loading state and cache gets populated for the current tweet URL, automatically update the modal to display the response cards
  - Implement a simple event-based or polling approach to check cache updates while modal is open
  - Keep the implementation simple and straightforward for MVP (e.g., use a callback or interval check)
  - Visible result: modal shows loading state initially, then automatically displays the 5 response cards once the background generation completes, without requiring the user to close and reopen the modal


- [x] Task 6: Implement temperature and sampling parameters for response diversity
  **Dev traceability Note: The program give way more helpfull response.**
  - Add temperature parameter to Grok API calls with a high value (1.5-2.0) to increase randomness
  - Add top_p parameter set to 0.95 or higher to sample from a wider token distribution
  - Add presence_penalty and frequency_penalty parameters (0.6-0.8 range) to discourage repetitive patterns across the 5 responses
  - Test different parameter combinations to find the sweet spot for maximum diversity while maintaining quality
  - Console.log the parameters being used for debugging
  - Visible result: the 5 generated responses show significantly more variation in style, tone, and content approach

- [ ] Task 7: Force diverse perspectives through prompt engineering
  **Dev Traceability Note: Reverted because it is inefficient. The responses are confusing and not really useful. The task is kept here for traceability.**
  - Update the system prompt to explicitly request 5 completely different opinions and approaches, including contrarian views
  - Add constraint that each response must use a different reasoning framework (e.g., analytical, emotional appeal, factual/data-driven, questioning/socratic, humorous/casual)
  - Modify the prompt to instruct the AI: "Generate 5 distinct replies with different perspectives. Each must differ in reasoning approach, tone, and opinion. Include contrarian or alternative viewpoints."
  - Add instruction to avoid similar sentence structures and vocabulary across responses
  - Test that responses now show genuine disagreement or different angles on the same tweet
  - Visible result: the 5 responses present noticeably different viewpoints, reasoning styles, and even conflicting opinions rather than variations of the same perspective
