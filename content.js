// Content script for X.com AI Reply Assistant
// This script will inject AI reply functionality into X.com pages

console.log('X.com AI Reply Assistant loaded');

// Storage key constant
const STORAGE_KEY = 'grokApiKey';

// Track which tweets already have our icon to avoid duplicates
const processedTweets = new WeakSet();

/**
 * Get the Grok API key from chrome.storage.sync
 * @returns {Promise<string|null>} The API key or null if not set
 */
async function getApiKey() {
  return new Promise((resolve) => {
    chrome.storage.sync.get([STORAGE_KEY], (result) => {
      resolve(result[STORAGE_KEY] || null);
    });
  });
}

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
  
  // Add click handler to open modal
  button.addEventListener('click', (e) => {
    e.stopPropagation();
    console.log('AI Reply icon clicked');
    openModal(button);
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

/**
 * Modal Management
 */

let currentModal = null;

/**
 * Create the modal HTML structure
 */
function createModal() {
  const modal = document.createElement('div');
  modal.className = 'ai-reply-modal-overlay';
  
  modal.innerHTML = `
    <div class="ai-reply-modal">
      <div class="ai-reply-modal-header">
        <h3 class="ai-reply-modal-title">AI Reply Generator</h3>
        <button class="ai-reply-modal-close" aria-label="Close modal">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
            <path d="M10.59 12L4.54 5.96l1.42-1.42L12 10.59l6.04-6.05 1.42 1.42L13.41 12l6.05 6.04-1.42 1.42L12 13.41l-6.04 6.05-1.42-1.42L10.59 12z"></path>
          </svg>
        </button>
      </div>
      
      <div class="ai-reply-modal-body">
        <div class="ai-reply-loading-area">
          <div class="ai-reply-spinner"></div>
          <p class="ai-reply-loading-text">Generating reply...</p>
        </div>
        
        <div class="ai-reply-preview-area" style="display: none;">
          <div class="ai-reply-preview-text"></div>
        </div>
      </div>
      
      <div class="ai-reply-modal-footer">
        <button class="ai-reply-insert-btn">Insert Reply</button>
      </div>
    </div>
  `;
  
  return modal;
}

/**
 * Update the loading text to show tweet excerpt
 */
function updateLoadingText(modal, tweetText) {
  const loadingTextElement = modal.querySelector('.ai-reply-loading-text');
  
  if (!loadingTextElement) return;
  
  // Create an excerpt (first 80 characters)
  const excerpt = tweetText.length > 80 
    ? tweetText.substring(0, 80) + '...' 
    : tweetText;
  
  loadingTextElement.textContent = `Generating reply for: "${excerpt}"`;
}

/**
 * Position the modal near the clicked button
 */
function positionModal(modal, anchorButton) {
  const modalContent = modal.querySelector('.ai-reply-modal');
  const rect = anchorButton.getBoundingClientRect();
  
  // Position below and slightly to the right of the button
  const top = rect.bottom + 8;
  const left = rect.left;
  
  modalContent.style.top = `${top}px`;
  modalContent.style.left = `${left}px`;
  
  // Ensure modal stays within viewport
  requestAnimationFrame(() => {
    const modalRect = modalContent.getBoundingClientRect();
    
    // Adjust if modal goes off right edge
    if (modalRect.right > window.innerWidth - 16) {
      modalContent.style.left = `${window.innerWidth - modalRect.width - 16}px`;
    }
    
    // Adjust if modal goes off bottom edge
    if (modalRect.bottom > window.innerHeight - 16) {
      modalContent.style.top = `${rect.top - modalRect.height - 8}px`;
    }
  });
}

/**
 * Extract tweet text from the DOM
 * Finds the original tweet that the user is replying to
 */
function extractTweetText(anchorButton) {
  // Strategy 1: Find the tweet article that contains the compose toolbar
  // The compose toolbar is inside the tweet article when replying inline
  let tweetArticle = anchorButton.closest('article[data-testid="tweet"]');
  
  // Strategy 2: If not found (e.g., in a modal or separate compose area),
  // look for the main tweet on the page
  if (!tweetArticle) {
    console.log('Not in tweet article, searching for main tweet on page');
    const allTweets = document.querySelectorAll('article[data-testid="tweet"]');
    
    // Get the first tweet (usually the one being replied to)
    if (allTweets.length > 0) {
      tweetArticle = allTweets[0];
    }
  }
  
  if (!tweetArticle) {
    console.warn('Could not find any tweet article on page');
    return null;
  }
  
  // Find the tweet text element within the article
  const tweetTextElement = tweetArticle.querySelector('[data-testid="tweetText"]');
  
  if (!tweetTextElement) {
    console.warn('Could not find tweet text element in article');
    return null;
  }
  
  // Extract the text content
  const tweetText = tweetTextElement.textContent.trim();
  console.log('Extracted tweet text:', tweetText);
  
  return tweetText;
}

/**
 * Open the modal
 */
async function openModal(anchorButton) {
  // Close existing modal if any
  if (currentModal) {
    closeModal();
  }

  // Check if API key is set
  const apiKey = await getApiKey();
  if (!apiKey) {
    // Show error message if no API key is configured
    alert('Please configure your Grok API key in the extension popup first.');
    return;
  }
  
  // Extract the tweet text
  const tweetText = extractTweetText(anchorButton);
  
  if (!tweetText) {
    alert('Could not extract tweet text. Please try again.');
    return;
  }
  
  // Create and add modal to DOM
  const modal = createModal();
  document.body.appendChild(modal);
  currentModal = modal;
  
  // Position the modal
  positionModal(modal, anchorButton);
  
  // Update loading text to show tweet excerpt
  updateLoadingText(modal, tweetText);
  
  // Add event listeners
  setupModalEventListeners(modal);
  
  // Animate in
  requestAnimationFrame(() => {
    modal.classList.add('ai-reply-modal-visible');
  });

  // TODO: In Task 6, call Grok API with tweetText and apiKey
  console.log('Ready to generate reply for tweet:', tweetText);
}

/**
 * Close the modal
 */
function closeModal() {
  if (!currentModal) return;
  
  // Animate out
  currentModal.classList.remove('ai-reply-modal-visible');
  
  // Remove from DOM after animation
  setTimeout(() => {
    if (currentModal && currentModal.parentNode) {
      currentModal.parentNode.removeChild(currentModal);
    }
    currentModal = null;
  }, 200);
}

/**
 * Setup event listeners for modal interactions
 */
function setupModalEventListeners(modal) {
  // Close button
  const closeBtn = modal.querySelector('.ai-reply-modal-close');
  closeBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    closeModal();
  });
  
  // Click outside to close
  modal.addEventListener('click', (e) => {
    if (e.target === modal) {
      closeModal();
    }
  });
  
  // Prevent clicks inside modal from closing it
  const modalContent = modal.querySelector('.ai-reply-modal');
  modalContent.addEventListener('click', (e) => {
    e.stopPropagation();
  });
  
  // Escape key to close
  const escapeHandler = (e) => {
    if (e.key === 'Escape') {
      closeModal();
      document.removeEventListener('keydown', escapeHandler);
    }
  };
  document.addEventListener('keydown', escapeHandler);
  
  // Insert button (placeholder for now)
  const insertBtn = modal.querySelector('.ai-reply-insert-btn');
  insertBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    console.log('Insert Reply clicked');
    // TODO: Insert reply into compose box (Task 7)
    closeModal();
  });
}
