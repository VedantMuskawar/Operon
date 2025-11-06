/**
 * Utility Functions for Client Migration
 */

/**
 * Normalizes phone number according to OPERON's logic (for duplicate checking)
 * - Remove all non-digit characters except + at the beginning
 * - Remove + if present (country codes)
 * - Remove leading zeros
 * - If number > 10 digits, take last 10 digits
 * 
 * @param {string} phone - Phone number to normalize
 * @returns {string} Normalized phone number (last 10 digits, no country code)
 */
function normalizePhoneNumber(phone) {
  if (!phone || typeof phone !== 'string') {
    return '';
  }

  // Remove all non-digit characters except + at the beginning
  let cleaned = phone.replace(/[^\d+]/g, '');
  
  // Remove + if present (country codes)
  let withoutCountryCode = cleaned.startsWith('+') 
    ? cleaned.substring(1) 
    : cleaned;
  
  // Remove leading zeros if any
  let normalized = withoutCountryCode;
  while (normalized.startsWith('0') && normalized.length > 1) {
    normalized = normalized.substring(1);
  }
  
  // If the number is longer than 10 digits, take last 10 digits
  if (normalized.length > 10) {
    normalized = normalized.substring(normalized.length - 10);
  }
  
  return normalized;
}

/**
 * Normalizes phone number while preserving country code
 * - Removes all non-digit characters except + at the beginning
 * - Preserves + and country code
 * - Removes leading zeros (but keeps country code)
 * - Ensures format: +[country code][number]
 * 
 * @param {string} phone - Phone number to normalize
 * @returns {string} Normalized phone number with country code (e.g., +91XXXXXXXXXX)
 */
function normalizePhoneNumberWithCountryCode(phone) {
  if (!phone || typeof phone !== 'string') {
    return '';
  }

  // Remove all non-digit characters except + at the beginning
  let cleaned = phone.replace(/[^\d+]/g, '');
  
  // Ensure it starts with +
  if (!cleaned.startsWith('+')) {
    // If no country code, assume India (+91) and add it
    // Remove leading zeros
    let withoutZeros = cleaned.replace(/^0+/, '');
    // If number is 10 digits, add +91 prefix
    if (withoutZeros.length === 10) {
      cleaned = '+91' + withoutZeros;
    } else {
      // Otherwise, add + prefix
      cleaned = '+' + withoutZeros;
    }
  }
  
  // Remove leading zeros after country code (but keep + and country code)
  // Example: +910123456789 -> +91123456789
  if (cleaned.startsWith('+')) {
    let afterPlus = cleaned.substring(1);
    // Remove leading zeros
    afterPlus = afterPlus.replace(/^0+/, '');
    cleaned = '+' + afterPlus;
  }
  
  return cleaned;
}

/**
 * Builds phoneList array from PaveBoard client data (as-is, no normalization)
 * Includes: primaryPhone, secondaryPhone, supervisor.primaryPhone
 * Filters out empty/null/undefined values
 * Stores phone numbers EXACTLY as they are in PaveBoard
 * 
 * @param {Object} paveClient - PaveBoard client document
 * @returns {string[]} Array of phone numbers as-is
 */
function buildPhoneListAsIs(paveClient) {
  const phoneList = [];
  
  // Primary phone - try multiple possible fields
  const primaryPhone = paveClient.contactInfo?.primaryPhone || 
                       paveClient.phoneNumber || 
                       paveClient.phone || 
                       '';
  if (primaryPhone && primaryPhone.trim()) {
    const phone = primaryPhone.trim();
    if (!phoneList.includes(phone)) {
      phoneList.push(phone);
    }
  }
  
  // Secondary phone
  if (paveClient.contactInfo?.secondaryPhone && paveClient.contactInfo.secondaryPhone.trim()) {
    const phone = paveClient.contactInfo.secondaryPhone.trim();
    if (!phoneList.includes(phone)) {
      phoneList.push(phone);
    }
  }
  
  // Supervisor primary phone
  if (paveClient.supervisor?.primaryPhone && paveClient.supervisor.primaryPhone.trim()) {
    const phone = paveClient.supervisor.primaryPhone.trim();
    if (!phoneList.includes(phone)) {
      phoneList.push(phone);
    }
  }
  
  return phoneList;
}

/**
 * Builds phoneList array from PaveBoard client data (legacy - for backward compatibility)
 * @deprecated Use buildPhoneListAsIs instead
 */
function buildPhoneList(paveClient) {
  return buildPhoneListAsIs(paveClient);
}

/**
 * Capitalizes a name string (first letter of each word)
 * 
 * @param {string} name - Name to capitalize
 * @returns {string} Capitalized name
 */
function capitalizeName(name) {
  if (!name || typeof name !== 'string') {
    return '';
  }
  
  // Split by spaces and capitalize first letter of each word
  return name
    .split(/\s+/)
    .map(word => {
      if (word.length === 0) return word;
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    })
    .join(' ')
    .trim();
}

/**
 * Transforms PaveBoard client data to OPERON client structure
 * 
 * @param {Object} paveClient - PaveBoard client document
 * @param {string} organizationId - OPERON organization ID
 * @returns {Object} OPERON client data structure
 */
function transformClientData(paveClient, organizationId) {
  // Try multiple possible phone number fields (PaveBoard might store it differently)
  const primaryPhone = paveClient.contactInfo?.primaryPhone || 
                       paveClient.phoneNumber || 
                       paveClient.phone || 
                       '';
  
  // Store phone number EXACTLY as it is from PaveBoard (no normalization)
  const phoneNumberAsIs = primaryPhone.trim();
  
  // Still normalize for duplicate checking (without country code)
  const normalizedPhoneForCheck = normalizePhoneNumber(primaryPhone);
  
  // Build phoneList with original phone numbers (as-is)
  const phoneList = buildPhoneListAsIs(paveClient);
  
  // Convert registeredTime (Firestore Timestamp) to Date
  let createdAt = new Date();
  if (paveClient.registeredTime) {
    if (paveClient.registeredTime.toDate) {
      createdAt = paveClient.registeredTime.toDate();
    } else if (paveClient.registeredTime._seconds) {
      createdAt = new Date(paveClient.registeredTime._seconds * 1000);
    } else if (paveClient.registeredTime instanceof Date) {
      createdAt = paveClient.registeredTime;
    }
  }
  
  // Capitalize the client name
  const capitalizedName = capitalizeName(paveClient.name || '');
  
  return {
    organizationId: organizationId,
    name: capitalizedName,
    phoneNumber: phoneNumberAsIs, // Store EXACTLY as it is from PaveBoard
    phoneList: phoneList,
    createdAt: createdAt,
    updatedAt: new Date(),
    status: 'active',
    // Keep normalized phone for duplicate checking (internal use)
    _normalizedPhoneForCheck: normalizedPhoneForCheck
  };
}

/**
 * Converts Date to Firestore Timestamp
 * 
 * @param {Date} date - Date object
 * @returns {Object} Firestore Timestamp object
 */
function dateToFirestoreTimestamp(date) {
  if (!date || !(date instanceof Date)) {
    date = new Date();
  }
  
  return {
    _seconds: Math.floor(date.getTime() / 1000),
    _nanoseconds: (date.getTime() % 1000) * 1000000
  };
}

/**
 * Formats date for console output
 * 
 * @param {Date} date - Date object
 * @returns {string} Formatted date string
 */
function formatDate(date) {
  if (!date) return 'N/A';
  return new Date(date).toISOString();
}

module.exports = {
  normalizePhoneNumber,
  normalizePhoneNumberWithCountryCode,
  buildPhoneList,
  buildPhoneListAsIs,
  capitalizeName,
  transformClientData,
  dateToFirestoreTimestamp,
  formatDate
};

