# Tasks — User-Draft-Driven Reply Generation

- [ ] Task 1: Remove the background prefetch and cache system
  - Strip out all prefetch, cache, URL-change-detection, and cache-listener code from content.js
  - Remove `responseCache`, `cacheUpdateListeners`, `addCacheUpdateListener`, `notifyCacheUpdate`, `prefetchResponseForCurrentTweet`, `clearStaleCache`, `handleUrlChange`, `initUrlChangeDetection`, `currentTweetUrl`
  - Remove the `history.pushState`/`replaceState` interception and the polling interval
  - Remove cache-related logic from `openModal()` (the cache check, the listener registration, `_removeCacheListener`)
  - Keep: `getApiKey()`, `extractMainTweetText()`, `callGrokAPI()`, icon injection, modal open/close, card display, clipboard logic
  - Visible result: Extension loads without errors, clicking ✨ opens an empty modal (loading state with no API call happening)

- [ ] Task 2: Add text input UI to the modal
  - Update `createModal()` to render: header, a `<textarea>` with placeholder like "Type your draft reply...", and a "Generate" button below it
  - Hide the loading area and cards container initially
  - Add CSS for the textarea (matching X.com dark theme) and the Generate button (blue, rounded, matching existing button styles)
  - Visible result: Clicking ✨ opens the modal with a textarea and Generate button. Nothing happens yet on click.

- [ ] Task 3: Wire Generate button to API call with updated prompt
  - Update `callGrokAPI()` to accept both `tweetText` and `userDraft` parameters
  - Update the system prompt to instruct the AI to expand/riff on the user's draft using the tweet as context
  - Update the user prompt to include both the tweet and the draft
  - On Generate click: validate textarea is not empty, hide input area, show loading spinner, call API, then call `showResponseCards()` with the results
  - Handle errors by showing an error message in the modal with a way to go back to the input
  - Visible result: Full end-to-end flow works — type a draft, click Generate, see loading, then 5 varied response cards appear. Clicking a card copies to clipboard and closes the modal.

- [ ] Task 4: Clean up dead code and polish
  - Remove `isTweetDetailPage()` and `getCurrentTweetUrl()` if no longer used
  - Remove the `extractTweetText(anchorButton)` function (replaced by `extractMainTweetText()` which is already used)
  - Ensure the modal body scrolls properly when 5 cards are displayed
  - Verify the textarea auto-focuses when modal opens for quick typing
  - Visible result: Clean codebase, no console warnings, smooth UX from open → type → generate → pick → clipboard.
