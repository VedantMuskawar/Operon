import {
  CLIENT_LEDGERS_COLLECTION,
  CLIENTS_COLLECTION,
  VENDOR_LEDGERS_COLLECTION,
  VENDORS_COLLECTION,
  EMPLOYEE_LEDGERS_COLLECTION,
  EMPLOYEES_COLLECTION,
} from '../shared/constants';

/**
 * Ledger types supported by the maintenance system
 */
export type LedgerType = 'client' | 'vendor' | 'employee';

/**
 * Configuration for each ledger type
 */
export interface LedgerConfig {
  collectionName: string;
  entityCollectionName: string;
  idField: 'clientId' | 'vendorId' | 'employeeId';
  balanceField: 'currentBalance';
}

/**
 * Ledger type configurations
 */
export const LEDGER_CONFIGS: Record<LedgerType, LedgerConfig> = {
  client: {
    collectionName: CLIENT_LEDGERS_COLLECTION,
    entityCollectionName: CLIENTS_COLLECTION,
    idField: 'clientId',
    balanceField: 'currentBalance',
  },
  vendor: {
    collectionName: VENDOR_LEDGERS_COLLECTION,
    entityCollectionName: VENDORS_COLLECTION,
    idField: 'vendorId',
    balanceField: 'currentBalance',
  },
  employee: {
    collectionName: EMPLOYEE_LEDGERS_COLLECTION,
    entityCollectionName: EMPLOYEES_COLLECTION,
    idField: 'employeeId',
    balanceField: 'currentBalance',
  },
};

/**
 * Get ledger configuration for a ledger type
 */
export function getLedgerConfig(ledgerType: LedgerType): LedgerConfig {
  return LEDGER_CONFIGS[ledgerType];
}

/**
 * Get ledger document ID from entity ID and financial year
 */
export function getLedgerId(entityId: string, financialYear: string): string {
  return `${entityId}_${financialYear}`;
}

/**
 * Result type for ledger validation
 */
export interface LedgerValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

/**
 * Result type for consistency check
 */
export interface ConsistencyCheckResult {
  consistent: boolean;
  entityBalance: number | null;
  ledgerBalance: number | null;
  difference: number;
}

/**
 * Result type for bulk ledger checks
 */
export interface LedgerCheckResult {
  ledgerType: LedgerType;
  ledgerId: string;
  entityId: string;
  organizationId: string;
  financialYear: string;
  valid: boolean;
  errors: string[];
  warnings: string[];
}

/**
 * Result type for rebuild operations
 */
export interface RebuildResult {
  ledgerType: LedgerType;
  ledgerId: string;
  entityId: string;
  organizationId: string;
  financialYear: string;
  success: boolean;
  previousBalance: number;
  newBalance: number;
  transactionCount: number;
  error?: string;
}
