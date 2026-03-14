// Popup script for Sleeping Bird
// This script handles the extension popup UI and API key management

console.log('Popup loaded');

// Storage key constant
const STORAGE_KEY = 'grokApiKey';

// DOM elements
let apiKeyInput;
let saveBtn;
let statusMessage;
let form;

// Initialize popup when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  // Get DOM elements
  apiKeyInput = document.getElementById('apiKey');
  saveBtn = document.getElementById('saveBtn');
  statusMessage = document.getElementById('statusMessage');
  form = document.getElementById('apiKeyForm');

  // Load existing API key
  loadApiKey();

  // Setup form submission
  form.addEventListener('submit', handleSave);
});

/**
 * Load the API key from chrome.storage.sync
 */
function loadApiKey() {
  chrome.storage.sync.get([STORAGE_KEY], (result) => {
    if (result[STORAGE_KEY]) {
      apiKeyInput.value = result[STORAGE_KEY];
      console.log('API key loaded from storage');
    }
  });
}

/**
 * Save the API key to chrome.storage.sync
 */
function handleSave(e) {
  e.preventDefault();

  const apiKey = apiKeyInput.value.trim();

  if (!apiKey) {
    // Don't save empty keys
    return;
  }

  // Disable button during save
  saveBtn.disabled = true;
  saveBtn.textContent = 'Saving...';

  // Save to chrome.storage.sync
  chrome.storage.sync.set({ [STORAGE_KEY]: apiKey }, () => {
    console.log('API key saved to storage');

    // Re-enable button
    saveBtn.disabled = false;
    saveBtn.textContent = 'Save Key';

    // Show success message
    showSuccessMessage();
  });
}

/**
 * Show the success message with checkmark
 */
function showSuccessMessage() {
  statusMessage.classList.add('visible');

  // Hide after 3 seconds
  setTimeout(() => {
    statusMessage.classList.remove('visible');
  }, 3000);
}

