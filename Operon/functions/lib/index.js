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
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
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
exports.transactions = exports.orders = exports.generateAccountsLedger = exports.rebuildLedgerTransactionsScheduled = exports.rebuildAllLedgersScheduled = void 0;
// Unified Ledger Maintenance Manager
__exportStar(require("./ledger-maintenance/LedgerMaintenanceManager"), exports);
// Ledger maintenance: sync CurrentBalance fields
__exportStar(require("./ledger-maintenance/syncCurrentBalance"), exports);
// Ledger maintenance scheduled rebuilds (export explicitly to avoid LedgerType ambiguity)
var rebuild_scheduled_1 = require("./ledger-maintenance/rebuild/rebuild-scheduled");
Object.defineProperty(exports, "rebuildAllLedgersScheduled", { enumerable: true, get: function () { return rebuild_scheduled_1.rebuildAllLedgersScheduled; } });
// Ledger maintenance: rebuild ledger transaction subcollections from TRANSACTIONS
var rebuild_ledger_transactions_1 = require("./ledger-maintenance/rebuild/rebuild-ledger-transactions");
Object.defineProperty(exports, "rebuildLedgerTransactionsScheduled", { enumerable: true, get: function () { return rebuild_ledger_transactions_1.rebuildLedgerTransactionsScheduled; } });
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
// Eager init Firestore for global caching (optional; getFirestore() also inits on first use)
const firestore_helpers_1 = require("./shared/firestore-helpers");
(0, firestore_helpers_1.getFirestore)();
// Re-export all Cloud Functions for Firebase deploy (root-level names required)
__exportStar(require("./analytics"), exports);
__exportStar(require("./clients"), exports);
__exportStar(require("./transactions"), exports);
__exportStar(require("./orders"), exports);
__exportStar(require("./vendors"), exports);
__exportStar(require("./raw-materials"), exports);
__exportStar(require("./cleanup"), exports);
__exportStar(require("./maintenance"), exports);
__exportStar(require("./production-batches"), exports);
__exportStar(require("./trip-wages"), exports);
__exportStar(require("./sync"), exports);
// export * from './ledger-maintenance'; // Removed to avoid LedgerType export ambiguity
var accounts_ledger_1 = require("./ledger-maintenance/accounts-ledger");
Object.defineProperty(exports, "generateAccountsLedger", { enumerable: true, get: function () { return accounts_ledger_1.generateAccountsLedger; } });
__exportStar(require("./employees/employee-analytics"), exports);
__exportStar(require("./employees/validate-ledger-access"), exports);
__exportStar(require("./geofences"), exports);
__exportStar(require("./edd"), exports);
__exportStar(require("./whatsapp/whatsapp-message-queue"), exports);
__exportStar(require("./whatsapp/whatsapp-webhook"), exports);
// Grouped exports (domain objects) for clarity
const ordersNs = __importStar(require("./orders"));
const transactionsNs = __importStar(require("./transactions"));
exports.orders = {
    onOrderDeleted: ordersNs.onOrderDeleted,
    onPendingOrderCreated: ordersNs.onPendingOrderCreated,
    onOrderUpdated: ordersNs.onOrderUpdated,
    onScheduledTripCreated: ordersNs.onScheduledTripCreated,
    onScheduledTripDeleted: ordersNs.onScheduledTripDeleted,
    onTripStatusUpdated: ordersNs.onTripStatusUpdated,
    generateDM: ordersNs.generateDM,
    cancelDM: ordersNs.cancelDM,
    onOrderCreatedSendWhatsapp: ordersNs.onOrderCreatedSendWhatsapp,
    onOrderUpdatedSendWhatsapp: ordersNs.onOrderUpdatedSendWhatsapp,
    onTripDispatchedSendWhatsapp: ordersNs.onTripDispatchedSendWhatsapp,
    onTripDeliveredSendWhatsapp: ordersNs.onTripDeliveredSendWhatsapp,
    deleteFullyScheduledOrdersWeekly: ordersNs.deleteFullyScheduledOrdersWeekly,
};
exports.transactions = {
    onTransactionCreated: transactionsNs.onTransactionCreated,
    onTransactionDeleted: transactionsNs.onTransactionDeleted,
    // rebuildClientLedgers removed: replaced by LedgerMaintenanceManager
};
//# sourceMappingURL=index.js.map