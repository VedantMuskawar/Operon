/**
 * Get ISO week number for a date
 * ISO week starts on Monday and week 1 is the first week with at least 4 days in the new year
 * Returns format: YYYY-Www (e.g., "2024-W14")
 */
export function getISOWeek(date: Date): string {
  const d = new Date(date);
  d.setUTCHours(0, 0, 0, 0);
  
  // Find the Thursday of the week (ISO week starts on Monday)
  const dayOfWeek = d.getUTCDay(); // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
  const thursdayOffset = dayOfWeek === 0 ? -3 : 4 - dayOfWeek;
  const thursday = new Date(d);
  thursday.setUTCDate(d.getUTCDate() + thursdayOffset);
  
  // January 4th is always in week 1
  const jan4 = new Date(Date.UTC(thursday.getUTCFullYear(), 0, 4));
  const jan4DayOfWeek = jan4.getUTCDay();
  const jan4ThursdayOffset = jan4DayOfWeek === 0 ? -3 : 4 - jan4DayOfWeek;
  const jan4Thursday = new Date(jan4);
  jan4Thursday.setUTCDate(jan4.getUTCDate() + jan4ThursdayOffset);
  
  // Calculate week number
  const daysDiff = Math.floor((thursday.getTime() - jan4Thursday.getTime()) / (1000 * 60 * 60 * 24));
  const weekNumber = Math.floor(daysDiff / 7) + 1;
  
  return `${thursday.getUTCFullYear()}-W${String(weekNumber).padStart(2, '0')}`;
}

/**
 * Format date as YYYY-MM-DD
 */
export function formatDate(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(date.getUTCDate()).padStart(2, '0')}`;
}

/**
 * Format date as YYYY-MM (for monthly breakdown)
 */
export function formatMonth(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}

/**
 * Clean up daily data older than specified days
 */
export function cleanDailyData(dailyData: Record<string, number>, keepDays: number): Record<string, number> {
  const cutoffDate = new Date();
  cutoffDate.setUTCDate(cutoffDate.getUTCDate() - keepDays);
  const cleaned: Record<string, number> = {};
  
  for (const [dateString, value] of Object.entries(dailyData)) {
    try {
      const parts = dateString.split('-');
      if (parts.length === 3) {
        const date = new Date(Date.UTC(
          parseInt(parts[0], 10),
          parseInt(parts[1], 10) - 1,
          parseInt(parts[2], 10)
        ));
        if (date >= cutoffDate) {
          cleaned[dateString] = value;
        }
      }
    } catch (e) {
      // Skip invalid date strings
    }
  }
  
  return cleaned;
}

/**
 * Get year-month string in format YYYY-MM for attendance/ledger documents
 * @param date - The date to format
 * @returns Year-month string (e.g., "2024-01" for January 2024)
 */
export function getYearMonth(date: Date): string {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

/**
 * Get year-month string in format YYYYMM for document IDs (compact format)
 * @param date - The date to format
 * @returns Year-month string (e.g., "202401" for January 2024)
 */
export function getYearMonthCompact(date: Date): string {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${year}${month}`;
}

/**
 * Normalize date to start of day for comparison
 * @param date - The date to normalize
 * @returns Date at start of day in UTC
 */
export function normalizeDate(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

/**
 * Get list of year-month strings (YYYY-MM) for a date range
 * @param startDate - Start date (inclusive)
 * @param endDate - End date (inclusive)
 * @returns Array of year-month strings (e.g., ["2024-04", "2024-05", "2024-06"])
 */
export function getMonthsInRange(startDate: Date, endDate: Date): string[] {
  const months: string[] = [];
  const current = new Date(startDate);
  current.setUTCDate(1); // Start from first day of month
  current.setUTCHours(0, 0, 0, 0);
  
  const end = new Date(endDate);
  end.setUTCDate(1);
  end.setUTCHours(0, 0, 0, 0);
  
  while (current <= end) {
    months.push(getYearMonth(current));
    // Move to next month
    current.setUTCMonth(current.getUTCMonth() + 1);
  }
  
  return months;
}

