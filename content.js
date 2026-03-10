// Content script for X.com AI Reply Assistant
// This script will inject AI reply functionality into X.com pages

console.log('X.com AI Reply Assistant loaded');

// Track which tweets already have our icon to avoid duplicates
const processedTweets = new WeakSet();

/**
 * Create the AI reply icon button
 */
function createAIReplyIcon() {
  const button = document.createElement('button');
  button.className = 'ai-reply-icon-btn';
  button.setAttribute('aria-label', 'Generate AI reply');
  button.setAttribute('type', 'button');
  
  // Use sparkle emoji as icon
  button.innerHTML = `
    <div class="ai-reply-icon-wrapper">
      <span class="ai-reply-icon">✨</span>
    </div>
  `;
  
  // Add click handler (will be used in later tasks)
  button.addEventListener('click', (e) => {
    e.stopPropagation();
    console.log('AI Reply icon clicked');
    // TODO: Open modal (Task 3)
  });
  
  return button;
}

/**
 * Inject AI reply icon into a compose toolbar
 */
function injectAIReplyIcon(toolbar) {
  // Avoid processing the same toolbar twice
  if (processedTweets.has(toolbar)) {
    return;
  }
  
  // Mark as processed
  processedTweets.add(toolbar);
  
  // Create a wrapper div with role="presentation" to match X.com's structure
  const wrapper = document.createElement('div');
  wrapper.setAttribute('role', 'presentation');
  wrapper.className = 'css-175oi2r r-14tvyh0 r-cpa5s6';
  
  // Create and append the icon
  const aiIcon = createAIReplyIcon();
  wrapper.appendChild(aiIcon);
  
  // Insert the wrapper into the toolbar
  // Try to insert it after the Grok button if it exists, otherwise append to the end
  const grokButton = toolbar.querySelector('[data-testid="grokImgGen"]');
  if (grokButton && grokButton.parentElement) {
    // Insert after the Grok button's wrapper
    grokButton.parentElement.insertAdjacentElement('afterend', wrapper);
  } else {
    // Fallback: append to the end
    toolbar.appendChild(wrapper);
  }
}

/**
 * Find and process all comment compose toolbars on the page
 */
function processActionBars() {
  // Target the compose toolbar with role="tablist" that contains image, GIF, Grok, emoji buttons
  // This is the toolbar in the reply/comment compose area
  const toolbars = document.querySelectorAll('[role="tablist"][data-testid="ScrollSnap-List"]');
  
  toolbars.forEach((toolbar) => {
    // Verify this is actually a compose toolbar by checking for typical buttons
    const hasGifButton = toolbar.querySelector('[data-testid="gifSearchButton"]');
    const hasGrokButton = toolbar.querySelector('[data-testid="grokImgGen"]');
    const hasFileInput = toolbar.querySelector('[data-testid="fileInput"]');
    
    // If it has at least one of these buttons, it's likely a compose toolbar
    const hasComposeButtons = hasGifButton || hasGrokButton || hasFileInput;
    
    if (hasComposeButtons && !processedTweets.has(toolbar)) {
      injectAIReplyIcon(toolbar);
    }
  });
}

/**
 * Set up MutationObserver to watch for new compose toolbars
 */
function initObserver() {
  // Process existing toolbars on page load
  processActionBars();
  
  // Watch for new compose areas being added (when opening reply, quote tweet, etc.)
  const observer = new MutationObserver((mutations) => {
    // Check if any new nodes were added
    let shouldProcess = false;
    
    for (const mutation of mutations) {
      if (mutation.addedNodes.length > 0) {
        shouldProcess = true;
        break;
      }
    }
    
    if (shouldProcess) {
      processActionBars();
    }
  });
  
  // Observe the entire document body for changes
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
  
  console.log('AI Reply icon injection observer initialized for compose toolbars');
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initObserver);
} else {
  initObserver();
}
