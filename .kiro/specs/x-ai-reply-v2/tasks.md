# Tasks - X.com AI Reply V2

- [x] Task 1: Remove the Insert Reply button and auto-insert on response selection
  - Remove the "Insert Reply" button from the modal footer
  - Remove the `ai-reply-modal-footer` section from the modal HTML and its CSS styles
  - When a response card is clicked, insert that reply directly into the composer and close the modal
  - Visible result: modal no longer has a footer with an Insert button; clicking a response inserts it

- [ ] Task 2: Start generating the AI response on post click (URL change detection)
  - Add a URL change listener (using `popstate`, `pushState`/`replaceState` interception, or polling) to detect when the user navigates to a tweet detail page (e.g. `/status/` URL pattern)
  - When a tweet detail page is detected, immediately extract the main tweet text and start calling the Grok API in the background (before the user clicks the ✨ icon)
  - Cache the generated responses keyed by tweet URL so they are ready instantly when the modal opens
  - Clear stale cache entries when navigating away from a tweet
  - Visible result: opening the modal on a tweet detail page shows responses almost instantly instead of waiting for the API

- [ ] Task 3: Generate 5 different responses per tweet
  - Update the Grok API call to request 5 completions (use `n: 5` parameter or make 5 parallel requests with varied temperature)
  - Store all 5 responses in the cache alongside the tweet URL
  - Visible result: API now returns 5 distinct reply options per tweet

- [ ] Task 4: Display the 5 responses as selectable cards in the modal
  - Replace the single preview text area with a scrollable list of 5 response cards
  - Each card shows the reply text with a subtle border and hover highlight
  - Clicking a card selects it visually (highlight border in blue) and inserts the reply into the composer, then closes the modal
  - If responses are still loading, show a spinner; as each response arrives, append its card progressively
  - Update modal CSS for the card layout (card container, individual card styles, selected state, hover state)
  - Visible result: modal displays 5 clickable response cards; clicking one inserts it and dismisses the modal
