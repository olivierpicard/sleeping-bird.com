// Content script for X.com AI Reply Assistant
// This script will inject AI reply functionality into X.com pages

console.log('X.com AI Reply Assistant loaded');

// Storage key constant
const STORAGE_KEY = 'grokApiKey';

// Track which tweets already have our icon to avoid duplicates
const processedTweets = new WeakSet();

// Cache for generated responses keyed by tweet URL
const responseCache = new Map();

// Track the current tweet URL to detect navigation
let currentTweetUrl = null;

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
 * Check if the current URL is a tweet detail page
 * @returns {boolean} True if on a tweet detail page
 */
function isTweetDetailPage() {
  return window.location.pathname.includes('/status/');
}

/**
 * Extract tweet URL from the current page
 * @returns {string|null} The tweet URL or null if not on a tweet detail page
 */
function getCurrentTweetUrl() {
  if (!isTweetDetailPage()) {
    return null;
  }
  
  // Extract the tweet URL from the current page URL
  // Format: https://x.com/username/status/1234567890
  const match = window.location.pathname.match(/\/status\/(\d+)/);
  if (match) {
    return window.location.pathname; // Use pathname as the cache key
  }
  
  return null;
}

/**
 * Extract tweet text from the main tweet on a detail page
 * @returns {string|null} The tweet text or null if not found
 */
function extractMainTweetText() {
  // Strategy 1: Try to find the main tweet article
  let mainTweet = document.querySelector('article[data-testid="tweet"]');
  
  // Strategy 2: If not found, try finding by role="article"
  if (!mainTweet) {
    const articles = document.querySelectorAll('article');
    if (articles.length > 0) {
      mainTweet = articles[0]; // First article is usually the main tweet
    }
  }
  
  if (!mainTweet) {
    console.warn('Could not find main tweet on detail page');
    return null;
  }
  
  // Find the tweet text element
  const tweetTextElement = mainTweet.querySelector('[data-testid="tweetText"]');
  
  if (!tweetTextElement) {
    console.warn('Could not find tweet text in main tweet');
    return null;
  }
  
  const tweetText = tweetTextElement.textContent.trim();
  
  if (!tweetText) {
    console.warn('Tweet text is empty');
    return null;
  }
  
  return tweetText;
}

/**
 * Start generating AI response in the background for the current tweet
 */
async function prefetchResponseForCurrentTweet() {
  const tweetUrl = getCurrentTweetUrl();
  
  if (!tweetUrl) {
    console.log('Not on a tweet detail page, skipping prefetch');
    return;
  }
  
  // Check if we already have a cached response
  if (responseCache.has(tweetUrl)) {
    console.log('Response already cached for:', tweetUrl);
    return;
  }
  
  // Get API key
  const apiKey = await getApiKey();
  if (!apiKey) {
    console.log('No API key configured, skipping prefetch');
    return;
  }
  
  // Extract tweet text
  const tweetText = extractMainTweetText();
  if (!tweetText) {
    console.log('Could not extract tweet text, skipping prefetch');
    return;
  }
  
  console.log('Starting background API call for tweet:', tweetUrl);
  
  // Call API in the background and cache the result (array of 5 responses)
  try {
    const generatedReplies = await callGrokAPI(tweetText, apiKey);
    responseCache.set(tweetUrl, generatedReplies);
    console.log('5 responses cached for:', tweetUrl);
  } catch (error) {
    console.error('Error prefetching response:', error);
    // Don't cache errors - let the modal handle them if user clicks
  }
}

/**
 * Clear stale cache entries when navigating away from a tweet
 */
function clearStaleCache() {
  const tweetUrl = getCurrentTweetUrl();
  
  // If we're not on a tweet detail page, clear the entire cache
  if (!tweetUrl) {
    if (responseCache.size > 0) {
      console.log('Clearing all cached responses (not on tweet detail page)');
      responseCache.clear();
    }
    return;
  }
  
  // If we're on a different tweet, clear old entries
  // Keep only the current tweet's cache
  const keysToDelete = [];
  for (const key of responseCache.keys()) {
    if (key !== tweetUrl) {
      keysToDelete.push(key);
    }
  }
  
  if (keysToDelete.length > 0) {
    console.log('Clearing stale cache entries:', keysToDelete);
    keysToDelete.forEach(key => responseCache.delete(key));
  }
}

/**
 * Handle URL changes and trigger background API calls
 */
function handleUrlChange() {
  const newTweetUrl = getCurrentTweetUrl();
  
  // Check if we've navigated to a different tweet or away from tweets
  if (newTweetUrl !== currentTweetUrl) {
    console.log('URL changed from', currentTweetUrl, 'to', newTweetUrl);
    currentTweetUrl = newTweetUrl;
    
    // Clear stale cache entries
    clearStaleCache();
    
    // If we're on a tweet detail page, start prefetching
    if (newTweetUrl) {
      // Wait a bit for the DOM to be ready
      setTimeout(() => {
        prefetchResponseForCurrentTweet();
      }, 500);
    }
  }
}

/**
 * Set up URL change detection
 */
function initUrlChangeDetection() {
  // Initial check on page load/refresh
  currentTweetUrl = getCurrentTweetUrl();
  if (currentTweetUrl) {
    console.log('Tweet detail page detected on load:', currentTweetUrl);
    // Wait for DOM to be ready before prefetching
    // Use a retry mechanism with increasing delays
    const attemptPrefetch = (retries = 5, delay = 1000) => {
      const tweetText = extractMainTweetText();
      if (tweetText) {
        console.log('Tweet text extracted successfully, starting prefetch');
        prefetchResponseForCurrentTweet();
      } else if (retries > 0) {
        console.log(`Tweet text not ready, retrying in ${delay}ms... (${retries} attempts left)`);
        setTimeout(() => attemptPrefetch(retries - 1, delay + 500), delay);
      } else {
        console.warn('Could not extract tweet text after multiple attempts');
      }
    };
    
    // Start attempting after a short initial delay
    setTimeout(() => attemptPrefetch(), 1000);
  }
  
  // Listen for popstate events (back/forward navigation)
  window.addEventListener('popstate', handleUrlChange);
  
  // Intercept pushState and replaceState to detect SPA navigation
  const originalPushState = history.pushState;
  const originalReplaceState = history.replaceState;
  
  history.pushState = function(...args) {
    originalPushState.apply(this, args);
    handleUrlChange();
  };
  
  history.replaceState = function(...args) {
    originalReplaceState.apply(this, args);
    handleUrlChange();
  };
  
  // Also poll for URL changes as a fallback (X.com uses SPA navigation)
  setInterval(handleUrlChange, 1000);
  
  console.log('URL change detection initialized');
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
  document.addEventListener('DOMContentLoaded', () => {
    initObserver();
    initUrlChangeDetection();
  });
} else {
  initObserver();
  initUrlChangeDetection();
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
    </div>
  `;
  
  return modal;
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
  
  // Create and add modal to DOM
  const modal = createModal();
  document.body.appendChild(modal);
  currentModal = modal;
  
  // Position the modal
  positionModal(modal, anchorButton);
  
  // Add event listeners
  setupModalEventListeners(modal);
  
  // Animate in
  requestAnimationFrame(() => {
    modal.classList.add('ai-reply-modal-visible');
  });

  // Check if we have a cached response for the current tweet
  const tweetUrl = getCurrentTweetUrl();
  const cachedResponses = tweetUrl ? responseCache.get(tweetUrl) : null;
  
  if (cachedResponses && Array.isArray(cachedResponses) && cachedResponses.length > 0) {
    console.log('Using cached responses for:', tweetUrl);
    // For now, display the first response (Task 4 will handle displaying all 5)
    showGeneratedReply(modal, cachedResponses[0]);
  } else {
    // No cached response - show loading state
    console.log('No cached response available, showing loading state');
    const loadingTextElement = modal.querySelector('.ai-reply-loading-text');
    if (loadingTextElement) {
      loadingTextElement.textContent = 'Generating response...';
    }
  }
}

/**
 * Call the Grok API to generate 5 thoughtful replies
 * @param {string} tweetText - The tweet text to reply to
 * @param {string} apiKey - The Grok API key
 * @returns {Promise<string[]>} Array of 5 generated reply texts
 */
async function callGrokAPI(tweetText, apiKey) {
  const endpoint = 'https://api.x.ai/v1/chat/completions';
  
  const systemPrompt = `You are a thoughtful twitter assistant. Your task is to craft insightful, valuable replies to tweets.

Guidelines:
- NO generic responses like "Great point!" or "Thanks for sharing"
- Bring a NEW angle, insight, or perspective to the conversation
- Be concise
- Be authentic
- Be positive
- Make humble yet very human-like response
- Use simple and basic vocabulary
- Use every day oral vocabulary
- Make the reply feel human, not AI-generated
- Add value through: a complementary insight, a constructive challenge, a useful resource, or an unpopullar opnion
- Let people knpw your conviction but respect others
- Avoid clichés and platitudes
- Make the sentence natural and human-like
- Use short sentences and emojis when appropriate
- Match the tone of the original tweet (professional, casual, humorous, etc.)`;

  const userPrompt = `Generate a thoughtful reply to this tweet:\n\n"${tweetText}"`;

  const requestBody = {
    model: 'grok-4-1-fast',
    messages: [
      {
        role: 'system',
        content: systemPrompt
      },
      {
        role: 'user',
        content: userPrompt
      }
    ],
    temperature: 0.8,
    max_tokens: 150,
    n: 5  // Request 5 different completions
  };

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    },
    body: JSON.stringify(requestBody)
  });

  if (!response.ok) {
    // Handle different error types
    if (response.status === 401) {
      throw new Error('Invalid API key. Please check your Grok API key in the extension popup.');
    } else if (response.status === 429) {
      throw new Error('Rate limit exceeded. Please try again in a few moments.');
    } else if (response.status >= 500) {
      throw new Error('Grok API service error. Please try again later.');
    } else {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error?.message || `API error: ${response.status}`);
    }
  }

  const data = await response.json();
  
  // Extract all 5 generated replies from the response
  if (!data.choices || data.choices.length === 0) {
    throw new Error('Unexpected API response format');
  }

  // Map all choices to their content and log them
  const replies = data.choices.map(choice => {
    if (!choice.message || !choice.message.content) {
      throw new Error('Unexpected API response format');
    }
    return choice.message.content.trim();
  });

  console.log('Generated 5 responses:', replies);
  
  return replies;
}

/**
 * Show the generated reply in the modal
 * @param {HTMLElement} modal - The modal element
 * @param {string} replyText - The generated reply text
 */
function showGeneratedReply(modal, replyText) {
  // Hide loading area
  const loadingArea = modal.querySelector('.ai-reply-loading-area');
  if (loadingArea) {
    loadingArea.style.display = 'none';
  }

  // Show preview area with the generated text
  const previewArea = modal.querySelector('.ai-reply-preview-area');
  const previewText = modal.querySelector('.ai-reply-preview-text');
  
  if (previewArea && previewText) {
    previewText.textContent = replyText;
    previewArea.style.display = 'block';
  }
}

/**
 * Show an error message in the modal
 * @param {HTMLElement} modal - The modal element
 * @param {string} errorMessage - The error message to display
 */
function showError(modal, errorMessage) {
  // Hide loading area
  const loadingArea = modal.querySelector('.ai-reply-loading-area');
  if (loadingArea) {
    loadingArea.style.display = 'none';
  }

  // Show error in preview area
  const previewArea = modal.querySelector('.ai-reply-preview-area');
  const previewText = modal.querySelector('.ai-reply-preview-text');
  
  if (previewArea && previewText) {
    previewText.innerHTML = `<div style="color: #f4212e; font-weight: 500;">⚠️ Error</div><div style="margin-top: 8px;">${errorMessage}</div>`;
    previewArea.style.display = 'block';
  }
}

/**
 * Insert the generated reply into X.com's reply composer
 * @param {string} replyText - The text to insert
 */
async function copyReplyToClipboard(replyText) {
  try {
    await navigator.clipboard.writeText(replyText);
    console.log('Reply text copied to clipboard');
    return true;
  } catch (err) {
    console.error('Failed to copy to clipboard:', err);
    return false;
  }
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
  
  // Click on preview area to insert reply
  const previewArea = modal.querySelector('.ai-reply-preview-area');
  previewArea.addEventListener('click', async (e) => {
    e.stopPropagation();
    console.log('Preview area clicked, copying reply to clipboard');
    
    // Get the generated reply text
    const previewText = modal.querySelector('.ai-reply-preview-text');
    if (!previewText) {
      console.error('Could not find preview text element');
      closeModal();
      return;
    }
    
    const replyText = previewText.textContent;
    if (!replyText || replyText.includes('⚠️ Error')) {
      console.error('No valid reply text to copy');
      closeModal();
      return;
    }
    
    // Copy the reply to clipboard
    const success = await copyReplyToClipboard(replyText);
    
    if (success) {
      // Show brief feedback that text was copied
      previewText.textContent = '✓ Copied to clipboard!';
      
      setTimeout(() => {
        closeModal();
      }, 500);
    } else {
      console.error('Failed to copy to clipboard');
      closeModal();
    }
  });
}
