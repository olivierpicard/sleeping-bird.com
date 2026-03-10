# Tasks - X.com AI Reply Chrome Extension (MVP)

- [x] Task 1: Scaffold the Chrome extension project structure
  - Create `manifest.json` (Manifest V3) with permissions for `x.com` only
  - Create empty `content.js`, `popup.html`, `popup.js`, `styles.css`
  - Add a 48x48 and 128x128 placeholder icon
  - Load the extension in Chrome via `chrome://extensions` and confirm it appears

- [x] Task 2: Inject the AI reply icon into the compose toolbar of reply/comment areas
  - In `content.js`, use a MutationObserver to detect compose toolbars on X.com (the bar with image, GIF, Grok, emoji buttons)
  - Append a small ✨ icon button next to the Grok button in the compose toolbar
  - Style it to blend with X.com's native icon row
  - Visible result: when composing a reply or comment, the AI icon appears in the toolbar next to Grok

- [x] Task 3: Build the dismissable modal UI
  - On icon click, open a small floating modal anchored near the tweet
  - Modal contains: a loading spinner area, a text preview area, an "Insert Reply" button, and a close (✕) button
  - Clicking outside or pressing Escape dismisses the modal
  - Style it to feel native to X.com (dark theme, rounded corners, subtle shadow)
  - Visible result: clicking the icon opens/closes the modal

- [x] Task 4: Add Grok API key management via the extension popup
  - In `popup.html` / `popup.js`, create a simple form: text input for the Grok API key + Save button
  - Store the key in `chrome.storage.sync`
  - Show a green checkmark or "Key saved" confirmation on save
  - In `content.js`, read the key from storage before making API calls
  - Visible result: user can open the extension popup, enter their key, and see it saved

- [ ] Task 5: Extract the tweet text on icon click
  - When the user clicks the AI icon on a tweet, grab the tweet's text content from the DOM
  - Pass it to the modal so it's ready for the API call
  - Visible result: the modal shows "Generating reply for: [tweet excerpt]..." while loading

- [ ] Task 6: Call the Grok API to generate a high-value reply
  - Use the stored API key to call the Grok API (xAI chat completions endpoint)
  - Send a prompt that instructs Grok to craft a thoughtful, reflective reply that adds value to the conversation
  - System prompt should emphasize: no generic responses, bring a new angle or insight, be concise
  - Display the generated reply in the modal's text preview area
  - Handle errors gracefully (missing key, network error, rate limit) with user-friendly messages
  - Visible result: after clicking the icon, the modal shows a generated reply

- [ ] Task 7: Insert the generated reply into X.com's reply field
  - On "Insert Reply" button click, find the tweet's reply composer input in the DOM
  - If the reply box isn't open, simulate a click on the native reply icon first to open it
  - Insert the generated text into the reply input field (handle X.com's contenteditable/draft.js input)
  - Dispatch appropriate input events so X.com recognizes the inserted text
  - Visible result: clicking "Insert Reply" populates the reply box with the AI-generated text, ready to send
