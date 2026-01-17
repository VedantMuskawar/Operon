"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LEDGER_CONFIGS = void 0;
exports.getLedgerConfig = getLedgerConfig;
exports.getLedgerId = getLedgerId;
const constants_1 = require("../shared/constants");
/**
 * Ledger type configurations
 */
exports.LEDGER_CONFIGS = {
    client: {
        collectionName: constants_1.CLIENT_LEDGERS_COLLECTION,
        entityCollectionName: constants_1.CLIENTS_COLLECTION,
        idField: 'clientId',
        balanceField: 'currentBalance',
    },
    vendor: {
        collectionName: constants_1.VENDOR_LEDGERS_COLLECTION,
        entityCollectionName: constants_1.VENDORS_COLLECTION,
        idField: 'vendorId',
        balanceField: 'currentBalance',
    },
    employee: {
        collectionName: constants_1.EMPLOYEE_LEDGERS_COLLECTION,
        entityCollectionName: constants_1.EMPLOYEES_COLLECTION,
        idField: 'employeeId',
        balanceField: 'currentBalance',
    },
};
/**
 * Get ledger configuration for a ledger type
 */
function getLedgerConfig(ledgerType) {
    return exports.LEDGER_CONFIGS[ledgerType];
}
/**
 * Get ledger document ID from entity ID and financial year
 */
function getLedgerId(entityId, financialYear) {
    return `${entityId}_${financialYear}`;
}
//# sourceMappingURL=ledger-types.js.map