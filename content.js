// Content script for Sleeping Bird
// This script will inject AI reply functionality into X.com pages



// Storage key constant
const STORAGE_KEY = 'grokApiKey';

// Track which tweets already have our icon to avoid duplicates
const processedTweets = new WeakSet();

// Track the current modal
let currentModal = null;

/**
 * Get the Grok API key from chrome.storage.sync
 * @returns {Promise<string|null>} The API key or null if not set
 */
async function getApiKey() {
  return new Promise((resolve, reject) => {
    // Check if chrome.storage is available
    if (typeof chrome === 'undefined' || !chrome.storage || !chrome.storage.sync) {
      reject(new Error('Extension not properly loaded. Please reload the extension.'));
      return;
    }
    
    chrome.storage.sync.get([STORAGE_KEY], (result) => {
      if (chrome.runtime.lastError) {
        reject(new Error(chrome.runtime.lastError.message));
        return;
      }
      resolve(result[STORAGE_KEY] || null);
    });
  });
}

/**
 * Extract tweet text from the DOM
 * @param {HTMLElement} anchorButton - The button that was clicked
 * @returns {string|null} The tweet text or null if not found
 */
function extractMainTweetText(anchorButton) {
  // Strategy 1: Find the tweet article that contains the compose toolbar
  // The compose toolbar is inside the tweet article when replying inline
  let tweetArticle = anchorButton.closest('article[data-testid="tweet"]');
  
  // Strategy 2: If not found (e.g., in a modal or separate compose area),
  // look for the main tweet on the page
  if (!tweetArticle) {

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

  
  return tweetText;
}

/**
 * Call the Grok API to generate reply variations
 * @param {string} tweetText - The original tweet text for context
 * @param {string} userDraft - The user's draft reply to expand on
 * @param {string} apiKey - The Grok API key
 * @returns {Promise<string[]>} Array of 5 generated reply variations
 */
async function callGrokAPI(tweetText, userDraft, apiKey) {
  const endpoint = 'https://api.x.ai/v1/chat/completions';
  
  const systemPrompt = `You are a thoughtful twitter assistant. Your task is to expand and riff on the user's draft reply, using the original tweet as context.

Guidelines:
- Take the user's draft as the main direction and creative seed
- Expand it into a complete, polished reply
- Use the original tweet as context to ensure relevance
- Create variations that explore different angles or tones of the same core idea
- Be concise but add depth and personality
- Make each variation feel natural and human
- Use simple, everyday vocabulary
- Add emojis sparingly when appropriate
- Match or slightly elevate the tone of the user's draft`;

  const userPrompt = `Original tweet: "${tweetText}"

User's draft reply: "${userDraft}"

Generate exactly 3 varied expansions of this draft reply. Each should capture the essence of the user's idea while adding polish, personality, and depth.

Format your response as 3 separate replies, each on its own line, numbered 1-3:

1. [First variation]
2. [Second variation]
3. [Third variation]`;

  const requestBody = {
    model: 'grok-4.20-beta-0309-non-reasoning',
    // model: 'grok-4-1-fast-non-reasoning',
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
    temperature: 1.8,  // High value for diversity across variations
    top_p: 0.95,
    max_tokens: 150*3  // Increased to accommodate 3 replies in one response
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
  
  // Extract the single response containing all 3 variations
  if (!data.choices || data.choices.length === 0) {
    throw new Error('Unexpected API response format');
  }

  const content = data.choices[0]?.message?.content;
  if (!content) {
    throw new Error('Unexpected API response format');
  }

  // Parse the numbered list into separate replies
  const replies = content
    .split('\n')
    .filter(line => line.trim().match(/^\d+\./))  // Find lines starting with numbers
    .map(line => line.replace(/^\d+\.\s*/, '').trim())  // Remove the number prefix
    .filter(reply => reply.length > 0)  // Remove empty entries
    .map(reply => reply.replace(/^["']+|["']+$/g, '')); // Remove surrounding quotes if any
    

  // Ensure we have exactly 3 replies
  if (replies.length < 3) {
    console.warn('Expected 3 replies but got', replies.length);
    // Pad with empty strings if needed
    while (replies.length < 3) {
      replies.push('');
    }
  }


  
  return replies.slice(0, 3);  // Return only the first 5
}

/**
 * Show the response cards in the modal
 * @param {HTMLElement} modal - The modal element
 * @param {string[]} responses - Array of generated reply texts
 */
function showResponseCards(modal, responses) {
  // Hide loading area
  const loadingArea = modal.querySelector('.ai-reply-loading-area');
  if (loadingArea) {
    loadingArea.style.display = 'none';
  }

  // Show cards container
  const cardsContainer = modal.querySelector('.ai-reply-cards-container');
  if (!cardsContainer) {
    console.error('Cards container not found');
    return;
  }

  // Clear any existing cards
  cardsContainer.innerHTML = '';

  // Create a card for each response
  responses.forEach((replyText, index) => {
    const card = document.createElement('div');
    card.className = 'ai-reply-card';
    card.setAttribute('data-index', index);
    card.textContent = replyText;

    // Add click handler to select and copy the reply
    card.addEventListener('click', async (e) => {
      e.stopPropagation();
      
      // Visual feedback - highlight the selected card
      card.classList.add('ai-reply-card-selected');
      
      // Copy to clipboard
      const success = await copyReplyToClipboard(replyText);
      
      if (success) {
        // Show brief feedback
        card.textContent = '✓ Copied to clipboard!';
        
        setTimeout(() => {
          closeModal();
        }, 500);
      } else {
        console.error('Failed to copy to clipboard');
        closeModal();
      }
    });

    cardsContainer.appendChild(card);
  });

  // Show the cards container
  cardsContainer.style.display = 'block';
}

/**
 * Insert the generated reply into X.com's reply composer
 * @param {string} replyText - The text to insert
 */
async function copyReplyToClipboard(replyText) {
  try {
    await navigator.clipboard.writeText(replyText);

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
function setupModalEventListeners(modal, anchorButton) {
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
  
  // Generate button click handler
  const generateBtn = modal.querySelector('.ai-reply-generate-btn');
  const textarea = modal.querySelector('.ai-reply-textarea');
  const inputArea = modal.querySelector('.ai-reply-input-area');
  const loadingArea = modal.querySelector('.ai-reply-loading-area');
  
  generateBtn.addEventListener('click', async (e) => {
    e.stopPropagation();
    
    // Validate textarea is not empty
    const userDraft = textarea.value.trim();
    if (!userDraft) {
      // Show validation feedback
      textarea.style.borderColor = '#f4212e';
      textarea.placeholder = 'Please type your draft reply first...';
      textarea.focus();
      
      // Reset border color after a moment
      setTimeout(() => {
        textarea.style.borderColor = '';
        textarea.placeholder = 'Type your draft reply...';
      }, 2000);
      
      return;
    }
    
    // Extract tweet text
    const tweetText = extractMainTweetText(anchorButton);
    if (!tweetText) {
      showErrorWithRetry(modal, 'Could not find the tweet text. Please try again.');
      return;
    }
    
    // Get API key
    const apiKey = await getApiKey();
    if (!apiKey) {
      showErrorWithRetry(modal, 'API key not found. Please set your Grok API key in the extension popup.');
      return;
    }
    
    // Hide input area and show loading
    inputArea.style.display = 'none';
    loadingArea.style.display = 'block';
    
    try {
      // Call API with both tweet text and user draft
      const responses = await callGrokAPI(tweetText, userDraft, apiKey);
      
      // Show response cards
      showResponseCards(modal, responses);
    } catch (error) {
      console.error('Error generating replies:', error);
      showErrorWithRetry(modal, error.message || 'Failed to generate replies. Please try again.');
    }
  });
}

/**
 * Show an error message in the modal with a retry button
 * @param {HTMLElement} modal - The modal element
 * @param {string} errorMessage - The error message to display
 */
function showErrorWithRetry(modal, errorMessage) {
  const loadingArea = modal.querySelector('.ai-reply-loading-area');
  const inputArea = modal.querySelector('.ai-reply-input-area');
  const cardsContainer = modal.querySelector('.ai-reply-cards-container');
  
  // Hide loading and cards
  if (loadingArea) loadingArea.style.display = 'none';
  if (cardsContainer) cardsContainer.style.display = 'none';
  
  // Clear cards container and show error
  if (cardsContainer) {
    cardsContainer.innerHTML = `
      <div class="ai-reply-error">
        <div class="ai-reply-error-icon">⚠️</div>
        <div class="ai-reply-error-message">${errorMessage}</div>
        <button class="ai-reply-retry-btn">Go Back</button>
      </div>
    `;
    cardsContainer.style.display = 'block';
    
    // Add retry button handler
    const retryBtn = cardsContainer.querySelector('.ai-reply-retry-btn');
    retryBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      
      // Hide error and show input area again
      cardsContainer.style.display = 'none';
      cardsContainer.innerHTML = '';
      inputArea.style.display = 'block';
      
      // Focus textarea
      const textarea = modal.querySelector('.ai-reply-textarea');
      if (textarea) textarea.focus();
    });
  }
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
  
  processedTweets.add(toolbar);
  
  // Create and insert the icon
  const icon = createAIReplyIcon();
  
  // Insert at the beginning of the toolbar
  toolbar.insertBefore(icon, toolbar.firstChild);
  

}

/**
 * Find and process all compose action bars on the page
 */
function processActionBars() {
  // Find all compose toolbars (reply, quote tweet, etc.)
  const toolbars = document.querySelectorAll('[data-testid="toolBar"]');
  
  toolbars.forEach(toolbar => {
    injectAIReplyIcon(toolbar);
  });
}

/**
 * Initialize the MutationObserver to watch for new compose areas
 */
function initObserver() {
  // Process existing toolbars on page load
  processActionBars();
  
  // Watch for new compose areas being added
  const observer = new MutationObserver((mutations) => {
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
  

}

/**
 * Create the modal HTML structure with textarea input
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
        <div class="ai-reply-input-area">
          <textarea 
            class="ai-reply-textarea" 
            placeholder="Type your draft reply..."
            rows="4"
          ></textarea>
          <button class="ai-reply-generate-btn">Generate</button>
        </div>
        
        <div class="ai-reply-loading-area" style="display: none;">
          <div class="ai-reply-spinner"></div>
          <p class="ai-reply-loading-text">Generating variations...</p>
        </div>
        
        <div class="ai-reply-cards-container" style="display: none;">
          <!-- Response cards will be dynamically inserted here -->
        </div>
      </div>
    </div>
  `;
  
  return modal;
}

/**
 * Position the modal at the top center of the screen
 */
function positionModal(modal) {
  const modalContent = modal.querySelector('.ai-reply-modal');
  
  // Center horizontally at the top of the viewport
  modalContent.style.top = '80px';
  modalContent.style.left = '50%';
  modalContent.style.transform = 'translateX(-50%)';
  modalContent.style.position = 'fixed';
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
  positionModal(modal);
  
  // Add event listeners
  setupModalEventListeners(modal, anchorButton);
  
  // Animate in
  requestAnimationFrame(() => {
    modal.classList.add('ai-reply-modal-visible');
  });
  
  // Auto-focus the textarea
  const textarea = modal.querySelector('.ai-reply-textarea');
  if (textarea) {
    setTimeout(() => textarea.focus(), 100);
  }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initObserver);
} else {
  initObserver();
}
