"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onVendorUpdated = exports.onVendorCreated = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const financial_year_1 = require("../shared/financial-year");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Generate vendor code in format: VND-{YYYY}-{NNN}
 * Example: VND-2024-001, VND-2024-002
 */
async function generateVendorCode(organizationId) {
    var _a;
    const currentYear = new Date().getFullYear();
    const yearPrefix = `VND-${currentYear}-`;
    // Query all vendors for this organization with codes starting with year prefix
    const vendorsSnapshot = await db
        .collection(constants_1.VENDORS_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('vendorCode', '>=', yearPrefix)
        .where('vendorCode', '<', `VND-${currentYear + 1}-`)
        .orderBy('vendorCode', 'desc')
        .limit(1)
        .get();
    let nextSequence = 1;
    if (!vendorsSnapshot.empty) {
        const lastCode = (_a = vendorsSnapshot.docs[0].data()) === null || _a === void 0 ? void 0 : _a.vendorCode;
        if (lastCode) {
            // Extract sequence number from last code (e.g., "VND-2024-001" -> 1)
            const match = lastCode.match(/-(\d{3})$/);
            if (match) {
                const lastSequence = parseInt(match[1], 10);
                nextSequence = lastSequence + 1;
            }
        }
    }
    // Format sequence with leading zeros (001, 002, etc.)
    const sequenceStr = String(nextSequence).padStart(3, '0');
    return `${yearPrefix}${sequenceStr}`;
}
/**
 * Create initial vendor ledger for current financial year
 */
async function createVendorLedger(vendorId, organizationId, openingBalance) {
    const { fyLabel: financialYear } = (0, financial_year_1.getFinancialContext)(new Date());
    const ledgerId = `${vendorId}_${financialYear}`;
    const ledgerRef = db.collection(constants_1.VENDOR_LEDGERS_COLLECTION).doc(ledgerId);
    const ledgerData = {
        ledgerId,
        vendorId,
        organizationId,
        financialYear,
        openingBalance,
        currentBalance: openingBalance,
        totalPayables: 0,
        totalPayments: 0,
        transactionCount: 0,
        creditCount: 0,
        debitCount: 0,
        transactionIds: [],
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };
    await ledgerRef.set(ledgerData);
    console.log('[Vendor Ledger] Created ledger', {
        ledgerId,
        vendorId,
        financialYear,
        openingBalance,
    });
}
/**
 * Cloud Function: Triggered when a vendor is created
 * - Auto-generates vendor code
 * - Creates initial ledger for current financial year
 * - Updates search indexes
 */
exports.onVendorCreated = (0, firestore_1.onDocumentCreated)(Object.assign({ document: `${constants_1.VENDORS_COLLECTION}/{vendorId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const vendorId = event.params.vendorId;
    const vendorData = snapshot.data();
    if (!vendorData) {
        console.warn('[Vendor] No data found for vendor', { vendorId });
        return;
    }
    const organizationId = vendorData.organizationId;
    if (!organizationId) {
        console.warn('[Vendor] Vendor created without organizationId', { vendorId });
        return;
    }
    const openingBalance = vendorData.openingBalance || 0;
    const name = vendorData.name || '';
    const phoneNumber = vendorData.phoneNumber;
    const phones = vendorData.phones || [];
    // Generate vendor code if not already set
    let vendorCode = vendorData.vendorCode;
    if (!vendorCode || vendorCode.trim() === '') {
        try {
            vendorCode = await generateVendorCode(organizationId);
            await snapshot.ref.update({
                vendorCode,
            });
            console.log('[Vendor] Generated vendor code', { vendorId, vendorCode });
        }
        catch (error) {
            console.error('[Vendor] Error generating vendor code', {
                vendorId,
                error,
            });
            // Continue even if code generation fails
        }
    }
    // Update search indexes
    const updates = {
        name_lowercase: name.toLowerCase(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    // Build phone index from all phones
    const phoneIndex = [];
    if (phoneNumber) {
        const normalized = phoneNumber.replace(/[^0-9+]/g, '');
        if (normalized)
            phoneIndex.push(normalized);
    }
    for (const phone of phones) {
        if (phone.normalized && !phoneIndex.includes(phone.normalized)) {
            phoneIndex.push(phone.normalized);
        }
    }
    if (phoneIndex.length > 0) {
        updates.phoneIndex = phoneIndex;
    }
    // Update phoneNumberNormalized if not set
    if (phoneNumber && !vendorData.phoneNumberNormalized) {
        updates.phoneNumberNormalized = phoneNumber.replace(/[^0-9+]/g, '');
    }
    await snapshot.ref.update(updates);
    // Create initial ledger for current financial year
    try {
        await createVendorLedger(vendorId, organizationId, openingBalance);
    }
    catch (error) {
        console.error('[Vendor] Error creating ledger', {
            vendorId,
            organizationId,
            error,
        });
    }
    console.log('[Vendor] Vendor created successfully', {
        vendorId,
        vendorCode,
        organizationId,
    });
});
/**
 * Cloud Function: Triggered when a vendor is updated
 * - Updates search indexes
 * - Validates status changes (prevents delete/suspend with non-zero balance)
 * - Prevents openingBalance and vendorCode updates
 */
exports.onVendorUpdated = (0, firestore_1.onDocumentUpdated)(Object.assign({ document: `${constants_1.VENDORS_COLLECTION}/{vendorId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    var _a, _b, _c;
    const vendorId = event.params.vendorId;
    const beforeData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const afterData = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    const afterRef = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after.ref;
    if (!beforeData || !afterData || !afterRef)
        return;
    if (!beforeData || !afterData) {
        console.warn('[Vendor] Missing data in update', { vendorId });
        return;
    }
    // Skip if only updatedAt changed (prevents infinite loops)
    const beforeUpdatedAt = beforeData.updatedAt;
    const afterUpdatedAt = afterData.updatedAt;
    const beforeKeys = Object.keys(beforeData).filter(k => k !== 'updatedAt');
    const afterKeys = Object.keys(afterData).filter(k => k !== 'updatedAt');
    // Check if only updatedAt changed
    if (beforeUpdatedAt !== afterUpdatedAt && beforeKeys.length === afterKeys.length) {
        let onlyUpdatedAtChanged = true;
        for (const key of beforeKeys) {
            if (JSON.stringify(beforeData[key]) !== JSON.stringify(afterData[key])) {
                onlyUpdatedAtChanged = false;
                break;
            }
        }
        if (onlyUpdatedAtChanged) {
            console.log('[Vendor] Only updatedAt changed, skipping to prevent infinite loop', { vendorId });
            return;
        }
    }
    const updates = {};
    // Update search indexes if name or phones changed
    const nameBefore = beforeData.name || '';
    const nameAfter = afterData.name || '';
    if (nameBefore !== nameAfter) {
        updates.name_lowercase = nameAfter.toLowerCase();
    }
    // Update phone index if phones changed
    const phonesBefore = beforeData.phones || [];
    const phonesAfter = afterData.phones || [];
    const phoneNumberAfter = afterData.phoneNumber || '';
    if (JSON.stringify(phonesBefore) !== JSON.stringify(phonesAfter) ||
        beforeData.phoneNumber !== phoneNumberAfter) {
        const phoneIndex = [];
        if (phoneNumberAfter) {
            const normalized = phoneNumberAfter.replace(/[^0-9+]/g, '');
            if (normalized)
                phoneIndex.push(normalized);
        }
        for (const phone of phonesAfter) {
            if (phone.normalized && !phoneIndex.includes(phone.normalized)) {
                phoneIndex.push(phone.normalized);
            }
        }
        if (phoneIndex.length > 0) {
            updates.phoneIndex = phoneIndex;
        }
    }
    // Validate: Prevent openingBalance updates
    const openingBalanceBefore = beforeData.openingBalance || 0;
    const openingBalanceAfter = afterData.openingBalance || 0;
    if (openingBalanceBefore !== openingBalanceAfter) {
        console.warn('[Vendor] Attempted to update openingBalance, reverting', {
            vendorId,
            before: openingBalanceBefore,
            after: openingBalanceAfter,
        });
        // Revert opening balance
        updates.openingBalance = openingBalanceBefore;
    }
    // Validate: Prevent vendorCode updates
    const vendorCodeBefore = beforeData.vendorCode || '';
    const vendorCodeAfter = afterData.vendorCode || '';
    if (vendorCodeBefore !== vendorCodeAfter && vendorCodeBefore !== '') {
        console.warn('[Vendor] Attempted to update vendorCode, reverting', {
            vendorId,
            before: vendorCodeBefore,
            after: vendorCodeAfter,
        });
        // Revert vendor code
        updates.vendorCode = vendorCodeBefore;
    }
    // Validate status changes
    const statusBefore = beforeData.status || 'active';
    const statusAfter = afterData.status || 'active';
    const currentBalance = afterData.currentBalance || 0;
    if (statusBefore !== statusAfter) {
        // Check if trying to delete or suspend with non-zero balance
        if ((statusAfter === 'deleted' || statusAfter === 'suspended') && currentBalance !== 0) {
            console.warn('[Vendor] Cannot delete/suspend vendor with pending balance', {
                vendorId,
                status: statusAfter,
                currentBalance,
            });
            // Revert status
            updates.status = statusBefore;
        }
    }
    // Only update timestamp if there are actual field changes
    // This prevents infinite loops where only updatedAt changes trigger another update
    const hasActualChanges = Object.keys(updates).length > 0;
    if (hasActualChanges) {
        updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await afterRef.update(updates);
        console.log('[Vendor] Updated vendor', { vendorId, updates });
    }
});
//# sourceMappingURL=vendor-handlers.js.map