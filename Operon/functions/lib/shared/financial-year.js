"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getFinancialContext = getFinancialContext;
/**
 * Calculate financial year context for a given date
 * Financial year starts in April (month 3, 0-indexed)
 */
function getFinancialContext(date) {
    const month = date.getUTCMonth(); // 0-based
    const year = date.getUTCFullYear();
    const fyStartYear = month >= 3 ? year : year - 1; // FY starts in April
    const fyLabel = `FY${String(fyStartYear % 100).padStart(2, '0')}${String((fyStartYear + 1) % 100).padStart(2, '0')}`;
    const monthKey = `${date.getUTCFullYear()}-${String(month + 1).padStart(2, '0')}`;
    const fyStart = new Date(Date.UTC(fyStartYear, 3, 1, 0, 0, 0));
    const fyEnd = new Date(Date.UTC(fyStartYear + 1, 3, 1, 0, 0, 0));
    return { fyLabel, fyStart, fyEnd, monthKey };
}
//# sourceMappingURL=financial-year.js.map