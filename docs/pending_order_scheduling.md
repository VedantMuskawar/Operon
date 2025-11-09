# Pending Order Scheduling Concept

## 1. Priority and Capacity Policy

### 1.1 Objectives
- Shorten time-to-commit for high-value orders and protect critical SLAs.
- Keep the backlog transparent so operations can intervene with confidence.
- Balance resource utilization against customer expectations and regulatory constraints.

### 1.2 Priority Score
```
priority_score = (w_sla * sla_urgency_index)
                + (w_value * net_margin_index)
                + (w_customer * customer_tier_index)
                + (w_readiness * readiness_index)
                + (w_risk * compliance_flag_index)
```
- `sla_urgency_index`: Bounded 0–1 score derived from minutes-to-breach for committed SLAs.
- `net_margin_index`: Relative contribution based on revenue minus expected fulfillment cost.
- `customer_tier_index`: Encodes VIP, strategic, standard tiers with decay over time.
- `readiness_index`: Measures fulfillment readiness (inventory committed, documentation complete, customer confirmed).
- `compliance_flag_index`: Applies surcharges for legal/regulatory obligations or penalties for risky attributes.
- Weight defaults: `w_sla=0.35`, `w_value=0.2`, `w_customer=0.15`, `w_readiness=0.2`, `w_risk=0.1`. Recalibrate quarterly.

### 1.3 SLA Tiers
- **Critical**: Promise < 4 hours. Auto page operations if backlog extends beyond 30 minutes.
- **High**: Promise same day. Escalate if projected breach in 90 minutes.
- **Standard**: Promise 48 hours. Batch scheduling allowed; escalate if breach risk > 8 hours.
- **Deferred**: Promise > 48 hours. Candidate for consolidation or manual scheduling.

### 1.4 Batching Rules
- Group orders with identical service region, skill requirements, and compatible time windows.
- Batch size capped by vehicle capacity or technician workload (default 6 orders or 3-hour block).
- Break batch if any order breach risk becomes > 70% or if override flagged.

### 1.5 Override Governance
- Manual override allowed for duty manager and above with reason code.
- All overrides logged with timestamp, operator, justification, and snapshot of priority inputs.
- Automated anomaly boost triggered when order attempts fail twice due to capacity conflicts.
- Weekly override audit ensures policy compliance; repeated misuse triggers retraining.

### 1.6 Capacity Model
- Maintain rolling 7-day capacity ledger per resource pool (technician, vehicle, warehouse).
- Include soft limits (preferred utilization) and hard limits (regulatory maximums).
- Reserve capacity for forecasted spikes (e.g., promotional events) via pre-allocation buckets.

## 2. Scheduling Engine Design

### 2.1 Flow Overview
1. **Intake**: Orders arrive via APIs, manual uploads, or partner feeds and land in a raw queue.
2. **Validation**: Schema and business-rule checks; failures routed to exception queue with alerts.
3. **Enrichment**: Append customer tier, inventory status, forecasted travel time, compliance tags.
4. **Prioritization**: Compute priority score; insert into tiered priority queues (Critical/High/Standard/Deferred).
5. **Capacity Check**: Evaluate candidate orders against capacity ledger using lookahead windows.
6. **Reservation**: Lock slots atomically to prevent double-booking; update ledger and order status.
7. **Dispatch**: Emit assignment to downstream fulfillment (routing engine, WMS, technician app).
8. **Confirmation**: Await acknowledgement; on failure, revert reservation and reinsert with penalty score.

### 2.2 Queue Structures
- Use segmented priority queues backed by Redis or equivalent with time-indexed buckets.
- Maintain FIFO within each priority bucket to preserve fairness.
- Implement dead-letter queue for orders exceeding configurable retry threshold.

### 2.3 Exception Handling
- Validation Failures: Route to ops dashboard with reason codes; auto-remind every 30 minutes.
- Capacity Conflicts: Move to waitlist, trigger forecast update, and schedule retry at 15-minute intervals.
- Downstream Failure: Increment failure counter, notify on-call, and provide last successful checkpoint.
- Inventory Backorder: Notify inventory management, flag order as pending-supply, suspend SLA countdown if policy permits.

### 2.4 Auditability
- Persist scheduling decisions with metadata (priority inputs, capacity snapshot, operator ID).
- Maintain immutable event log for each order to support post-mortems and compliance reviews.
- Provide replay tool to simulate alternative policy weightings for what-if analysis.

## 3. Order Lifecycle Diagram (Textual)
```
Customer/Partner
  -> Intake API / Upload
      -> Validation Service
          -> Enrichment Service
              -> Priority Queue (by tier)
                  -> Scheduler Loop
                      -> Capacity Ledger
                          -> Assignment Dispatch
                              -> Fulfillment System
                                  -> Completion / Exception Feedback
```
- Alternative branches:
  - Validation failure -> Exception Queue -> Ops Manual Fix -> Re-intake.
  - Capacity shortfall -> Waitlist -> Capacity Refresh -> Scheduler Loop.
  - Manual Override -> Priority Queue with boosted score -> Scheduler Loop.

## 4. Operational Monitoring

### 4.1 Core KPIs
- `Backlog_by_Tier`: Count of pending orders per SLA tier.
- `SLA_Adherence`: Percent of orders scheduled before breach threshold.
- `Avg_Scheduling_Latency`: Median time from intake to assignment.
- `Capacity_Utilization`: Actual vs planned utilization per resource pool.
- `Override_Rate`: Share of orders touched manually.

### 4.2 Leading Indicators
- `Ingestion_Latency`: Time from source system to intake confirmation.
- `Validation_Failure_Rate`: Percentage of orders failing initial checks.
- `Forecast_Variance`: Difference between predicted and actual order volume.
- `Resource_Availability`: Headcount vs plan, absenteeism alerts, vehicle downtime.
- `Inventory_Fill_Rate`: Ready-to-ship percentage for SKU dependencies.

### 4.3 Alerting
- Critical alert when Critical-tier backlog > 10 orders or any breach imminent within 15 minutes.
- High-severity alert for ingestion latency > 5 minutes sustained for 3 intervals.
- Medium alert for override rate > 8% rolling 24 hours.
- Auto-generated incident for validation failures > 3% with link to runbook and Slack bridge.

### 4.4 Reporting Cadence
- Real-time dashboards for NOC/operations with 1-minute refresh.
- Daily email digest summarizing backlog, breaches, overrides, top root causes.
- Weekly policy review deck with trends, experiments, and recommended weight changes.
- Monthly executive scorecard aligning with financial and customer satisfaction metrics.

## 5. Risk Register

| Risk Category      | Description | Impact | Likelihood | Mitigation |
|--------------------|-------------|--------|------------|------------|
| Data Integrity     | Missing or stale attributes leading to mis-prioritized orders. | High | Medium | Redundant feeds, strict validation, reconciliation jobs, data quality ownership. |
| Capacity Shocks    | Sudden demand surge or resource outage causing SLA breaches. | High | Medium | Flex staffing agreements, surge playbooks, automated waitlist prioritization, scenario drills. |
| Policy Drift       | Excessive manual overrides eroding trust in automation. | Medium | Medium | Override approvals, audit logs, weekly governance review, training reinforcement. |
| Compliance Failure | Breaching regulatory delivery windows or privacy obligations. | High | Low | Embedded compliance rules, legal checkpoints, restricted data access, continuous monitoring. |
| Tool Adoption      | Operators bypassing system due to complexity or poor UX. | Medium | Medium | User-centered training, feedback loop, phased rollout, UX refinements. |
| Integration Outage | Downstream systems unavailable, halting dispatch. | High | Medium | Graceful degradation, message retries, failover endpoints, incident escalation matrix. |

## 6. Current Pending-Order CRUD Flow

### 6.1 Firestore Collections
- `ORDERS`: Root collection storing order documents with `orderId`, `organizationId`, `clientId`, `status`, financials, trip counts, and metadata (`createdBy`, `updatedBy`, timestamps, notes).
- `ORGANIZATIONS/{orgId}/VEHICLES`: Subcollection per organization holding vehicle capacity (`weeklyCapacity` map), status, and driver assignments.

### 6.2 CRUD Responsibilities
- **Create**: `AndroidOrderRepository.createOrder` assembles a normalized payload, stamps metadata, and saves to `ORDERS`. Default `status` is `pending`.
- **Read**: `getPendingOrders` plus `watchPendingOrders` pull real-time snapshots limited by organization; UI surfaces client-level views via `watchOrdersByClient`.
- **Update**: `updateOrder` refreshes timestamps, supports both logical updates (e.g., status change) and data edits; uses `orderId` then falls back to document id for resilience.
- **Delete**: `deleteOrder` removes canceled records after verifying ownership; operations typically prefer status transitions over hard deletes.
- **Vehicles CRUD**: `VehicleRepository` mirrors the pattern for creation, updates, driver assignment, and deletions while exposing `weeklyCapacity` for consumption by the scheduler.

### 6.3 Pending → Scheduled Lifecycle Today
1. Intake (mobile/web/partner) triggers `createOrder`.
2. Pending orders surface in UI/streams for operations review.
3. Ops manually assigns vehicle/technician outside automated scheduling and then calls `updateOrder` to set new status (`confirmed`, `completed`, etc.).
4. Reporting snapshots use `getPendingOrders` to quantify backlog by status.

## 7. Target Scheduling Lifecycle (Pending → Scheduled)

### 7.1 Step-by-Step Flow
1. **Ingest** order (existing create flow).
2. **Assess** readiness: enrichment service calculates priority inputs (SLA, value, tier, readiness, compliance).
3. **Prioritize**: compute weighted score, slot order into tiered queue.
4. **Analyze Capacity**: translate `weeklyCapacity` into per-slot availability for vehicles and technicians; include real-time utilization.
5. **Reserve** resources: atomic update to capacity ledger, write reservation metadata back to the order (assigned vehicle, time window, dispatcher info).
6. **Dispatch**: push assignment to fulfillment; wait for ack.
7. **Monitor**: track lifecycle events (scheduled, dispatched, fulfilled, exception).
8. **Adapt**: on failure, re-queue with penalty, escalate to overrides dashboard, or quarantine for manual fix.

### 7.2 Combined Flow Diagram (Textual)
```
 Client / Partner App
        |
        v
   Intake API
        |
        v
Validation & Enrichment ----> Exception Queue (if failed)
        |
        v
Priority Queues (Critical/High/Standard/Deferred)
        |
        v
Scheduler Loop
   |        \
   |         --> Waitlist (capacity conflict)
   v
Capacity Ledger (Vehicles, Technicians, Inventory)
        |
        v
Dispatch Service ---> Fulfillment Systems
        |
        v
Completion Events / Metrics Store
```

### 7.3 Data Touchpoints
- Order document gains scheduling fields: `priorityScore`, `slaTier`, `scheduledAt`, `scheduledWindow`, `assignedVehicleId`, `assignedTechnicianId`, `reservationToken`, `schedulerVersion`.
- Capacity ledger persists availability snapshots per resource (e.g., `VEHICLE_CAPACITY/{vehicleId}/{date}` with remaining slots).
- Audit log collection (e.g., `ORDER_EVENTS`) captures transitions and overrides.

## 8. Database / Schema Overview

### 8.1 Order Document (Firestore)
| Field | Type | Description |
|-------|------|-------------|
| `orderId` | `String` | External/business identifier (falls back to doc id). |
| `organizationId` | `String` | Partition key for multi-tenant isolation. |
| `clientId` | `String` | Reference to customer record. |
| `status` | `String` | `pending`, `confirmed`, `completed`, `cancelled`. |
| `items` | `Array<Map>` | Line items with product/quantity/price. |
| `deliveryAddress` | `Map` | Structured address fields. |
| `region` / `city` / `locationId` | `String` | Routing metadata. |
| `subtotal` / `totalAmount` | `Double` | Financial amounts. |
| `trips` | `Int` | Planned trips count. |
| `paymentType` | `String` | Payment method. |
| `priorityScore` | `Double` | Calculated field (future). |
| `slaTier` | `String` | Critical / High / Standard / Deferred. |
| `scheduledWindow` | `Map` | `{start: Timestamp, end: Timestamp}`. |
| `assignedVehicleId` | `String` | Link to vehicle doc. |
| `assignedTechnicianId` | `String` | Link to technician/employee doc. |
| `reservationToken` | `String` | Idempotent reservation marker. |
| `createdAt` / `updatedAt` | `Timestamp` | Lifecycle metadata. |
| `createdBy` / `updatedBy` | `String` | Operator IDs. |
| `notes` | `String` | Optional ops notes. |

### 8.2 Vehicle Document
| Field | Type | Description |
|-------|------|-------------|
| `vehicleID` / `vehicleNo` | `String` | Unique fleet identifiers. |
| `type` | `String` | Tractor, truck, etc. |
| `status` | `String` | Active, Maintenance, etc. |
| `weeklyCapacity` | `Map<String, Int>` | Slots per weekday (e.g., `{Mon: 12}`). |
| `assignedDriverId` / `Name` / `Contact` | `String` | Linked driver metadata. |
| `createdAt` / `updatedAt` | `Timestamp` | Audit fields. |
| `createdBy` / `updatedBy` | `String` | Operator IDs. |

### 8.3 Capacity Ledger (Proposed)
| Field | Type | Description |
|-------|------|-------------|
| `resourceType` | `String` | `vehicle`, `technician`, `warehouse`. |
| `resourceId` | `String` | Reference ID. |
| `date` | `Date` | Capacity date. |
| `timeBucket` | `String` | e.g., `2025-11-08T10:00Z`. |
| `availableSlots` | `Int` | Remaining capacity. |
| `heldSlots` | `Int` | Reserved but not confirmed. |
| `utilization` | `Double` | Derived metric. |
| `updatedAt` | `Timestamp` | Last ledger update. |
| `reservationTokens` | `Array<String>` | Idempotent reservation IDs. |

## 9. Detailed Use-Case Scenario

### 9.1 Morning Surge Example
1. **09:00** – 25 orders ingested (5 Critical, 10 High, 8 Standard, 2 Deferred). Firestore now holds documents with `status=pending`.
2. **09:02** – Validation/enrichment service flags one Critical order missing compliance document; order moved to exception queue with `notes` updated via `updateOrder`.
3. **09:05** – Priority scores calculated; queue orders accordingly. Vehicle capacities for Monday extracted from `weeklyCapacity` (e.g., `Truck-12` has 8 slots left after previous reservations).
4. **09:10** – Scheduler reserves slots for the top 6 orders across two vehicles, writing `assignedVehicleId`, `scheduledWindow`, `reservationToken`, and `status=confirmed`. Capacity ledger decrements slots atomically.
5. **09:15** – Waitlist receives 3 High-tier orders because vehicle capacity saturates; alert triggers staffing escalation.
6. **09:20** – Ops resolves missing compliance doc; order re-enters queue with boosted score (override logged in audit collection).
7. **09:30** – Deferred orders grouped into a single route scheduled for 15:00, optimizing shared location and skill set.
8. **10:00** – Fulfillment systems acknowledge assignments; scheduler transitions orders to `status=completed` upon confirmation, releasing reservations in the capacity ledger.
9. **10:15** – Dashboards show backlog reduction, SLA adherence at 96%, capacity utilization at 82%, override rate 4%—all within thresholds.

### 9.2 Exception Path
- A scheduled High-tier order fails dispatch because of vehicle breakdown. Capacity ledger reclaims slot; order status reverts to `pending` with penalty score, and the engine retries next best vehicle. If retries fail twice, operations receives override alert and may manually reassign.

## 6. Continuous Improvement Loop
- Collect post-scheduling feedback from fulfillment outcomes (first-time fix rate, customer feedback).
- Feed learnings into quarterly policy calibration and capacity planning updates.
- Run A/B tests on priority weights and batching thresholds with control holdouts.
- Maintain backlog of enhancement requests linked to metrics to justify investments.

