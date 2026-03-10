# X.com AI Reply Chrome Extension - Installation Guide

## Loading the Extension in Chrome

1. Open Chrome and navigate to `chrome://extensions/`

2. Enable "Developer mode" by toggling the switch in the top-right corner

3. Click the "Load unpacked" button

4. Navigate to this project directory and select it

5. The extension should now appear in your extensions list with the name "X.com AI Reply Assistant"

6. You should see the ✨ icon in your Chrome toolbar

## Verifying the Installation

- The extension should appear in your extensions list at `chrome://extensions/`
- You should see:
  - Name: "X.com AI Reply Assistant"
  - Version: 1.0.0
  - Status: Enabled
  - The extension icon (✨) in your toolbar

## Testing

- Navigate to https://x.com (or https://twitter.com)
- Open the browser console (F12) and check for the message: "X.com AI Reply Assistant loaded"
- Click the extension icon in the toolbar to open the popup

## Troubleshooting

If the extension doesn't load:
- Check that all required files are present (manifest.json, content.js, popup.html, popup.js, styles.css, icons/)
- Look for errors in the Chrome extensions page
- Check the browser console for any error messages
