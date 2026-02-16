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
exports.onProductionBatchDeleted = exports.onProductionBatchCreated = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const function_config_1 = require("../shared/function-config");
const constants_1 = require("../shared/constants");
const db = (0, firestore_helpers_1.getFirestore)();
const RAW_MATERIALS_COLLECTION = 'RAW_MATERIALS';
const STOCK_HISTORY_COLLECTION = 'STOCK_HISTORY';
/**
 * Decrease raw material stock when a production batch is created
 */
exports.onProductionBatchCreated = (0, firestore_1.onDocumentCreated)(Object.assign({ document: `${constants_1.PRODUCTION_BATCHES_COLLECTION}/{batchId}` }, function_config_1.STANDARD_TRIGGER_OPTS), async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const batch = snapshot.data();
    const batchId = event.params.batchId;
    const organizationId = batch === null || batch === void 0 ? void 0 : batch.organizationId;
    const rawMaterialsUsed = batch === null || batch === void 0 ? void 0 : batch.rawMaterialsUsed;
    const createdBy = batch === null || batch === void 0 ? void 0 : batch.createdBy;
    const batchDate = batch === null || batch === void 0 ? void 0 : batch.batchDate;
    const createdAt = batchDate || admin.firestore.Timestamp.now();
    if (!organizationId) {
        console.error('[Stock] Missing organizationId in production batch', { batchId });
        return;
    }
    if (!rawMaterialsUsed || rawMaterialsUsed.length === 0) {
        console.log('[Stock] No raw materials used in production batch', { batchId });
        return;
    }
    console.log('[Stock] Processing raw materials consumption for batch', {
        batchId,
        organizationId,
        materialCount: rawMaterialsUsed.length,
    });
    try {
        await db.runTransaction(async (transaction) => {
            const materialRefs = [];
            for (const material of rawMaterialsUsed) {
                const materialId = material.materialId;
                const quantity = material.quantity;
                if (!materialId || quantity <= 0) {
                    console.warn('[Stock] Invalid material usage in batch', {
                        batchId,
                        materialId,
                        quantity,
                    });
                    continue;
                }
                const materialRef = db
                    .collection('ORGANIZATIONS')
                    .doc(organizationId)
                    .collection(RAW_MATERIALS_COLLECTION)
                    .doc(materialId);
                materialRefs.push({
                    ref: materialRef,
                    materialId,
                    material,
                });
            }
            const materialDocs = await Promise.all(materialRefs.map(({ ref }) => transaction.get(ref)));
            const updates = [];
            for (let i = 0; i < materialRefs.length; i++) {
                const { ref, materialId, material } = materialRefs[i];
                const materialDoc = materialDocs[i];
                if (!materialDoc.exists) {
                    console.warn('[Stock] Material not found for batch consumption', {
                        batchId,
                        materialId,
                        organizationId,
                    });
                    continue;
                }
                const materialData = materialDoc.data();
                const currentStock = materialData.stock || 0;
                const balanceBefore = currentStock;
                const balanceAfter = Math.max(0, currentStock - material.quantity);
                const historyEntryId = `${batchId}_${materialId}`;
                const historyRef = ref.collection(STOCK_HISTORY_COLLECTION).doc(historyEntryId);
                updates.push({
                    materialRef: ref,
                    historyRef,
                    balanceBefore,
                    balanceAfter,
                    quantity: material.quantity,
                    materialId,
                    material,
                });
            }
            for (const update of updates) {
                transaction.update(update.materialRef, {
                    stock: update.balanceAfter,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                const historyEntry = {
                    entryId: `${batchId}_${update.materialId}`,
                    materialId: update.materialId,
                    type: 'out',
                    quantity: update.quantity,
                    balanceBefore: update.balanceBefore,
                    balanceAfter: update.balanceAfter,
                    reason: 'production_batch',
                    batchId: batchId,
                    notes: `Production batch consumption: ${update.quantity} ${update.material.unitOfMeasurement || ''}`,
                    createdBy: createdBy || 'system',
                    createdAt: createdAt,
                };
                transaction.set(update.historyRef, historyEntry);
                console.log('[Stock] Prepared batch consumption update', {
                    batchId,
                    materialId: update.materialId,
                    quantity: update.quantity,
                    balanceBefore: update.balanceBefore,
                    balanceAfter: update.balanceAfter,
                });
            }
            console.log('[Stock] Transaction prepared for batch consumption', {
                batchId,
                materialCount: updates.length,
            });
        });
        console.log('[Stock] Successfully processed batch consumption', {
            batchId,
            materialCount: rawMaterialsUsed.length,
        });
    }
    catch (error) {
        console.error('[Stock] Error processing batch consumption', {
            batchId,
            error: error instanceof Error ? error.message : String(error),
            stack: error instanceof Error ? error.stack : undefined,
        });
    }
});
/**
 * Reverse raw material stock when a production batch is deleted
 */
exports.onProductionBatchDeleted = (0, firestore_1.onDocumentDeleted)(Object.assign({ document: `${constants_1.PRODUCTION_BATCHES_COLLECTION}/{batchId}` }, function_config_1.STANDARD_TRIGGER_OPTS), async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const batch = snapshot.data();
    const batchId = event.params.batchId;
    const organizationId = batch === null || batch === void 0 ? void 0 : batch.organizationId;
    const rawMaterialsUsed = batch === null || batch === void 0 ? void 0 : batch.rawMaterialsUsed;
    if (!organizationId) {
        console.error('[Stock] Missing organizationId in deleted batch', { batchId });
        return;
    }
    if (!rawMaterialsUsed || rawMaterialsUsed.length === 0) {
        console.log('[Stock] No raw materials used in deleted batch', { batchId });
        return;
    }
    console.log('[Stock] Reversing raw materials for deleted batch', {
        batchId,
        organizationId,
        materialCount: rawMaterialsUsed.length,
    });
    try {
        await db.runTransaction(async (transaction) => {
            const materialRefs = [];
            for (const material of rawMaterialsUsed) {
                const materialId = material.materialId;
                const quantity = material.quantity;
                if (!materialId || quantity <= 0) {
                    console.warn('[Stock] Invalid material usage in deleted batch', {
                        batchId,
                        materialId,
                        quantity,
                    });
                    continue;
                }
                const materialRef = db
                    .collection('ORGANIZATIONS')
                    .doc(organizationId)
                    .collection(RAW_MATERIALS_COLLECTION)
                    .doc(materialId);
                materialRefs.push({
                    ref: materialRef,
                    materialId,
                    material,
                });
            }
            const materialDocs = await Promise.all(materialRefs.map(({ ref }) => transaction.get(ref)));
            const originalHistoryRefs = materialRefs.map(({ ref, materialId }) => {
                const originalHistoryEntryId = `${batchId}_${materialId}`;
                return ref.collection(STOCK_HISTORY_COLLECTION).doc(originalHistoryEntryId);
            });
            const originalHistoryDocs = await Promise.all(originalHistoryRefs.map((ref) => transaction.get(ref)));
            const updates = [];
            for (let i = 0; i < materialRefs.length; i++) {
                const { ref, materialId, material } = materialRefs[i];
                const materialDoc = materialDocs[i];
                const originalHistoryDoc = originalHistoryDocs[i];
                if (!materialDoc.exists) {
                    console.warn('[Stock] Material not found for deleted batch reversal', {
                        batchId,
                        materialId,
                        organizationId,
                    });
                    continue;
                }
                const materialData = materialDoc.data();
                const currentStock = materialData.stock || 0;
                const balanceBefore = currentStock;
                const balanceAfter = currentStock + material.quantity;
                const originalHistoryEntryId = `${batchId}_${materialId}`;
                const reversalHistoryEntryId = `${batchId}_${materialId}_reversal`;
                const originalHistoryRef = ref.collection(STOCK_HISTORY_COLLECTION).doc(originalHistoryEntryId);
                const reversalHistoryRef = ref.collection(STOCK_HISTORY_COLLECTION).doc(reversalHistoryEntryId);
                updates.push({
                    materialRef: ref,
                    originalHistoryRef,
                    originalHistoryExists: originalHistoryDoc.exists,
                    reversalHistoryRef,
                    balanceBefore,
                    balanceAfter,
                    quantity: material.quantity,
                    materialId,
                    material,
                });
            }
            for (const update of updates) {
                transaction.update(update.materialRef, {
                    stock: update.balanceAfter,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                const historyEntry = {
                    entryId: `${batchId}_${update.materialId}_reversal`,
                    materialId: update.materialId,
                    type: 'in',
                    quantity: update.quantity,
                    balanceBefore: update.balanceBefore,
                    balanceAfter: update.balanceAfter,
                    reason: 'production_batch_deletion',
                    batchId: batchId,
                    notes: `Production batch deleted: returned ${update.quantity} ${update.material.unitOfMeasurement || ''}`,
                    createdBy: 'system',
                    createdAt: admin.firestore.Timestamp.now(),
                };
                transaction.set(update.reversalHistoryRef, historyEntry);
                if (update.originalHistoryExists) {
                    transaction.delete(update.originalHistoryRef);
                }
                console.log('[Stock] Prepared batch reversal update', {
                    batchId,
                    materialId: update.materialId,
                    quantity: update.quantity,
                    balanceBefore: update.balanceBefore,
                    balanceAfter: update.balanceAfter,
                });
            }
            console.log('[Stock] Transaction prepared for batch reversal', {
                batchId,
                materialCount: updates.length,
            });
        });
        console.log('[Stock] Successfully reversed batch materials', {
            batchId,
            materialCount: rawMaterialsUsed.length,
        });
    }
    catch (error) {
        console.error('[Stock] Error reversing batch materials', {
            batchId,
            error: error instanceof Error ? error.message : String(error),
            stack: error instanceof Error ? error.stack : undefined,
        });
    }
});
//# sourceMappingURL=raw-materials-stock-handlers.js.map