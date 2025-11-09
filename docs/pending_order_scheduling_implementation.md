# Pending Order Scheduling Implementation Plan

This document turns the conceptual scheduling model into an actionable implementation roadmap. It complements `docs/pending_order_scheduling.md`.

## 1. Policy Sign-off Package

### 1.1 Decision Summary
- **SLA tiers**: Critical (<4h), High (same day), Standard (48h), Deferred (>48h).
- **Priority weights**: `w_sla=0.35`, `w_value=0.20`, `w_readiness=0.20`, `w_customer=0.15`, `w_risk=0.10`.
- **Override governance**:
  - Duty manager+ may escalate with reason code.
  - Automated anomaly boost after two capacity conflicts.
  - Weekly audit; repeated misuse escalated to operations leadership.
- **Batching guardrails**:
  - Max 6 orders or 3-hour service block per batch.
  - Break batch if breach risk >70% or override present.
- **Capacity policies**:
  - Rolling 7-day ledger with soft and hard limits per resource.
  - Pre-allocation buckets for forecasted spikes (campaigns, events).

### 1.2 Stakeholder Matrix
| Area | Approver | Inputs Needed | Sign-off Artifact |
|------|----------|---------------|-------------------|
| SLA tiers & weights | Head of Ops | Historical SLA breach rates, margin data | SLA policy doc |
| Override rules | Ops Duty Managers | Incident logs, manual escalation data | Override runbook |
| Capacity assumptions | Fleet & Workforce Leads | Staffing plans, vehicle capacity tables | Capacity governance note |
| Compliance flags | Legal & Risk | Regulatory constraints, penalties | Compliance checklist |

### 1.3 Success Criteria
- SLA adherence ≥ 95% for Critical tier.
- Manual override rate < 10% post-launch.
- No compliance breaches tied to scheduling decisions.

## 2. Data Model & Schema Extensions

### 2.1 Order Document Additions
- `priorityScore: double`
- `slaTier: string`
- `scheduledWindow: {start: Timestamp, end: Timestamp}`
- `assignedVehicleId: string`
- `assignedTechnicianId: string`
- `reservationToken: string`
- `schedulerVersion: string`
- `schedulingStatus: string` (enum: `pending`, `queued`, `scheduled`, `dispatched`, `completed`, `exception`)

Migration approach:
1. Backfill `slaTier` based on existing promised dates.
2. Initialize `schedulingStatus` as `pending` for current records.
3. Add composite indexes on `(organizationId, status, schedulingStatus)` and `(organizationId, slaTier, schedulingStatus)`.

### 2.2 Capacity Ledger Collections
- `RESOURCE_CAPACITY/{resourceType}/{resourceId}/LEDGER/{date}` documents containing:
  - `timeBuckets: Map<String, {available: int, held: int, utilization: double}>`
  - `lastSyncedFromWeeklyCapacity: Timestamp`
  - `updatedBy: string`
  - `notes: string`
- Transactional subcollection `reservations` capturing:
  - `reservationToken`
  - `orderId`
  - `requestedWindow`
  - `status` (`held`, `confirmed`, `released`, `expired`)

### 2.3 Audit Trail
- New collection `ORDER_EVENTS` with append-only records:
  - `orderId`, `eventType`, `payload`, `initiatedBy`, `createdAt`, `reasonCode`.
- Streamed to BigQuery / warehouse for analytics.

## 3. Enrichment Service Specification

### 3.1 Responsibilities
- Listen to `ORDERS` changes where `status=pending` and `schedulingStatus='pending'`.
- Validate mandatory fields (delivery window, region, required skills).
- Fetch dependent data: customer tier, historical margin, inventory readiness, compliance requirements.
- Compute normalized indices (`sla_urgency_index`, `net_margin_index`, etc.) and assemble `priorityScore`.
- Determine `slaTier` using promised date vs SLA thresholds.
- Persist enriched fields back to Firestore via idempotent update.
- Emit enrichment metrics (latency, failure count).

### 3.2 Technical Footprint
- Implementation target: Cloud Functions (Node.js) or Cloud Run (Dart/Go) depending on team preference.
- Use Firestore change streams (Document Change API) with deduplication by `reservationToken`.
- Include retry logic with exponential backoff; send failures to `ENRICHMENT_ERRORS` topic for ops review.

### 3.3 Interfaces
- **Input**: Firestore document snapshot (`Order`).
- **Output**: Updated `Order` document fields; optional queue message to scheduler (Pub/Sub).
- **Config**: YAML/Firestore config for weight overrides, threshold adjustments.

## 4. Scheduler Service Design

### 4.1 Core Loop
1. Pull highest-priority orders from queue where `schedulingStatus='queued'`.
2. For each candidate:
   - Evaluate capacity ledger for compatible vehicles/technicians.
   - Use transaction to hold slot (`held`) and update ledger counts.
   - Update order: set `schedulingStatus='scheduled'`, `scheduledWindow`, assignee IDs, `reservationToken`.
3. Push dispatch instruction (Pub/Sub / REST) to fulfillment system.
4. Track acknowledgements; if ack fails, release reservation and downgrade score with penalty.

### 4.2 Components
- **Priority Queue**: Redis Sorted Set / Firestore + Pub/Sub hybrid.
- **Capacity Adapter**: Module to translate route/time requirements into ledger lookups.
- **Conflict Resolver**: Handles slot contention, escalates to waitlist after N retries.
- **Dead-letter Manager**: Moves problematic orders to `exception` status with reason codes.

### 4.3 Scalability & Resilience
- Horizontal scaling via stateless workers; ensure idempotent reservation tokens.
- Use distributed locks (e.g., Firestore transactions with deterministic doc IDs) to avoid double booking.
- Circuit breaker for downstream dispatch service (fallback to manual queue).

### 4.4 Telemetry
- Metrics: scheduling throughput, reservation success rate, retry counts, waitlist dwell time.
- Tracing: correlate enrichment → scheduling → dispatch events.

## 5. Capacity Synchronization

### 5.1 Daily Sync Job
- Reads `weeklyCapacity` from `VEHICLES`.
- Projects next 7 days into ledger, adjusting for planned maintenance and known outages.
- Flags discrepancies (e.g., missing vehicle entries) to ops dashboard.

### 5.2 Real-time Adjustments
- When vehicle status changes (maintenance, inactive), trigger reduction of available slots.
- Support manual adjustments via admin UI: update ledger and propagate to scheduler.
- Integrate with workforce management API for technician availability.

### 5.3 Forecast Integration
- Ingest demand forecasts; pre-allocate buffer capacity buckets.
- Provide interfaces to override capacity for special events.

## 6. Ops Tooling & Governance

### 6.1 Dashboards
- **Backlog View**: by SLA tier, region, scheduling status.
- **Capacity Heatmap**: vehicle/technician utilization by time bucket.
- **Exception Queue**: validation failures, waitlisted orders, override requests.

### 6.2 Override Workflow
- Web form to escalate order with reason code, optional attachment.
- Enforces role-based permissions; logs event to `ORDER_EVENTS`.
- Schedules automatic review in weekly governance meeting.

### 6.3 Runbooks
- SLA breach response, capacity shock mitigation, dispatch outage playbook.
- Postmortem template for scheduling incidents.

## 7. Observability & Compliance

### 7.1 KPIs & Alerts
- `Critical_SLA_Adherence`, `Average_Scheduling_Latency`, `Capacity_Utilization`, `Override_Rate`.
- Alert thresholds:
  - Critical SLA adherence < 95% for 3 consecutive intervals.
  - Capacity utilization > 90% for > 2 hours (potential overload).
  - Enrichment failure rate > 3% in 30 minutes.

### 7.2 Logs & Audits
- Centralize structured logs (orderId, reservationToken, action, latency).
- Nightly export to warehouse for compliance audit.
- Privacy controls: mask PII fields; apply access policies via IAM.

### 7.3 Governance Cadence
- Daily standup review of alerts.
- Weekly policy review meeting with Ops, Fleet, Support.
- Monthly scorecard to leadership with KPI trends and experiment results.

## 8. Rollout Strategy

1. **Shadow Mode**: Run enrichment and scheduler in read-only simulation; compare outputs to current manual process.
2. **Dark Launch**: Enable capacity reservations and dispatch for Deferred/Standard tiers while keeping manual override as fallback.
3. **Progressive Enablement**: Gradually include High, then Critical tiers once metrics stabilize.
4. **Post-launch Monitoring**: Track KPIs hourly; maintain rollback toggle in case of sustained SLA impact.
5. **Retrospective**: 30-day review to recalibrate weights, capacity assumptions, and tooling gaps.

## 9. Open Questions & Next Steps

- Confirm technology choice (Cloud Functions vs Cloud Run vs backend service) based on team capacity.
- Define schema migration scripts and backfill tooling.
- Align with analytics team on warehouse models for new telemetry.
- Schedule stakeholder sign-off sessions (Ops, Fleet, Support, Legal).

---
Maintainers: Operations Engineering Team  
Last updated: <!--TODO:update-date-->2025-11-08

