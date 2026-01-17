import { onCall } from 'firebase-functions/v2/https';
import { CALLABLE_FUNCTION_CONFIG } from '../../shared/function-config';
import { logInfo, logWarning, logError } from '../../shared/logger';
import {
  LedgerType,
  ConsistencyCheckResult,
  getLedgerConfig,
  getLedgerId,
} from '../ledger-types';

const { getFirestore } = require('firebase-admin/firestore');
const db = getFirestore();

/**
 * Check if entity.currentBalance matches ledger.currentBalance
 */
export const checkLedgerConsistency = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    try {
      const { ledgerType, entityId, organizationId, financialYear } = request.data;

      logInfo('LedgerMaintenance', 'checkLedgerConsistency', 'Checking consistency', {
        ledgerType,
        entityId,
        organizationId,
        financialYear,
      });

      // Validate input
      if (!ledgerType || !entityId || !organizationId || !financialYear) {
        throw new Error('Missing required parameters: ledgerType, entityId, organizationId, financialYear');
      }

      if (!['client', 'vendor', 'employee'].includes(ledgerType)) {
        throw new Error(`Invalid ledgerType: ${ledgerType}. Must be 'client', 'vendor', or 'employee'`);
      }

      const config = getLedgerConfig(ledgerType as LedgerType);
      const ledgerId = getLedgerId(entityId, financialYear);

      // Get entity document
      const entityRef = db.collection(config.entityCollectionName).doc(entityId);
      const entityDoc = await entityRef.get();

      if (!entityDoc.exists) {
        throw new Error(`Entity document not found: ${entityId} in ${config.entityCollectionName}`);
      }

      // Get ledger document
      const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
      const ledgerDoc = await ledgerRef.get();

      if (!ledgerDoc.exists) {
        logWarning('LedgerMaintenance', 'checkLedgerConsistency', 'Ledger document not found', {
          ledgerType,
          ledgerId,
          entityId,
        });

        return {
          consistent: false,
          entityBalance: (entityDoc.data()?.[config.balanceField] as number) || null,
          ledgerBalance: null,
          difference: (entityDoc.data()?.[config.balanceField] as number) || 0,
        } as ConsistencyCheckResult;
      }

      const entityData = entityDoc.data()!;
      const ledgerData = ledgerDoc.data()!;

      const entityBalance = (entityData[config.balanceField] as number) ?? null;
      const ledgerBalance = (ledgerData.currentBalance as number) ?? null;

      // Check if both are null/undefined
      if (entityBalance === null && ledgerBalance === null) {
        return {
          consistent: true,
          entityBalance: null,
          ledgerBalance: null,
          difference: 0,
        } as ConsistencyCheckResult;
      }

      if (entityBalance === null || ledgerBalance === null) {
        logWarning('LedgerMaintenance', 'checkLedgerConsistency', 'One balance is null', {
          ledgerType,
          entityId,
          entityBalance,
          ledgerBalance,
        });

        return {
          consistent: false,
          entityBalance,
          ledgerBalance,
          difference: Math.abs((entityBalance || 0) - (ledgerBalance || 0)),
        } as ConsistencyCheckResult;
      }

      // Check if balances match (allow small floating point differences)
      const difference = Math.abs(entityBalance - ledgerBalance);
      const consistent = difference < 0.01; // Allow 0.01 difference for floating point

      if (!consistent) {
        logWarning('LedgerMaintenance', 'checkLedgerConsistency', 'Balance mismatch detected', {
          ledgerType,
          entityId,
          entityBalance,
          ledgerBalance,
          difference,
        });
      } else {
        logInfo('LedgerMaintenance', 'checkLedgerConsistency', 'Balances are consistent', {
          ledgerType,
          entityId,
          balance: entityBalance,
        });
      }

      return {
        consistent,
        entityBalance,
        ledgerBalance,
        difference,
      } as ConsistencyCheckResult;
    } catch (error) {
      logError(
        'LedgerMaintenance',
        'checkLedgerConsistency',
        'Error checking consistency',
        error instanceof Error ? error : String(error),
        request.data,
      );

      throw error;
    }
  },
);
