---
name: message-queues
description: >
  Design, diagnose, and safely operate brokered delivery with Kafka, RabbitMQ, and compatible queues: acknowledgements, retries, dead letters, ordering, lag, and replay.
license: MIT
metadata:
  source: iuliandita/skills
  date_added: "2026-09-20"
  effort: high
  argument_hint: "[broker-or-symptom]"
---

# Message Queues

Design and diagnose asynchronous delivery without inventing guarantees the broker or application
does not provide. Make the delivery contract explicit: who owns a message, when an effect is safe
to repeat, how poison messages stop blocking progress, and how recovery avoids replaying more than
intended.

## When to use

- Designing Kafka, RabbitMQ, or compatible producer and consumer delivery behavior
- Investigating consumer lag, growing queues, duplicate effects, redeliveries, or stuck messages
- Choosing acknowledgement, retry, dead-letter, ordering, backpressure, retention, or replay rules
- Reviewing an event-driven workflow for idempotency, observability, and failure recovery

## When NOT to use

- The failing layer is unknown during a live outage; use **debug-triage** to localize it first
- Building generic telemetry pipelines, alerts, SLOs, or dashboards; use **observability**
- Modeling a database transaction, schema, outbox table, or data-store recovery; use **databases**
- Designing HTTP, GraphQL, or gRPC request contracts; use **backend-api**
- Editing Kubernetes, Terraform, or broker deployment configuration; use the matching infrastructure skill

## Workflow

### 1. State the contract before changing settings

Record producer success, broker durability, consumer acknowledgement point, retry limit, ordering
scope, retention, and the permitted duplicate/loss window. "Exactly once" only applies to a stated
broker-to-consumer boundary; an external side effect still needs an idempotency key or a transactional
outbox/inbox protocol.

### 2. Trace one message through normal and failure paths

For a representative message, trace publish -> broker acceptance -> delivery -> durable business
effect -> acknowledgement/offset commit. Then trace process crash after the effect, timeout, malformed
payload, dependency outage, and retry exhaustion. Place the acknowledgement only after the durable
effect, and make duplicate delivery harmless.

### 3. Bound pressure and failure handling

- Limit in-flight work to consumer capacity. RabbitMQ prefetch bounds unacknowledged deliveries;
  Kafka consumers need bounded poll/worker handoff and processing that stays within the group timeout.
- Retry only transient, classified failures with capped attempts and delayed or scheduled backoff.
  Do not immediate-requeue every failure: it can create a hot redelivery loop.
- Send exhausted, malformed, or permanently rejected messages to a dead-letter destination with the
  original payload, stable message ID, failure reason, attempt count, and source location. A DLQ is
  a recovery queue, not a discard bin: assign ownership, alerting, and a repair/replay procedure.
- Preserve order only where the broker can: Kafka orders within a partition and a RabbitMQ queue has
  delivery order constraints that competing consumers, priorities, requeues, and retries can disturb.
  Choose a key/partition or a single ordered consumer deliberately; never claim global order by default.

### 4. Diagnose from read-only evidence

Compare ingress rate, egress/ack rate, consumer count, in-flight messages, retry/redelivery rate,
oldest-message age, DLQ rate, and Kafka consumer-group lag. A rising backlog with steady consumer
throughput suggests insufficient capacity or increased input; high in-flight work plus slow acks
suggests downstream saturation; repeating message IDs suggest a retry or idempotency defect.
Inspect one correlation/message ID across producer, broker, consumer, and effect records before
changing prefetch, scaling consumers, resetting offsets, purging queues, or replaying data.

### 5. Recover with a scoped, measurable plan

Choose a finite message range, target consumer group/queue, idempotency protection, expected
side effects, stop condition, and before/after lag or backlog measurement. Test replay on a
non-production copy or a quarantined message first. Offset reset, purge, requeue, or broad replay
changes delivery state: obtain explicit authorization after presenting the exact scope and rollback
or containment plan.

## AI Self-Check

- [ ] Delivery guarantee names match the chosen producer, broker, consumer, and side-effect boundary
- [ ] Acknowledgement/offset commit follows the durable effect and a crash can safely redeliver
- [ ] Retryable and terminal errors are classified; attempts, backoff, and DLQ ownership are explicit
- [ ] Message identity and idempotency cover producer retry, redelivery, and replay
- [ ] Ordering claim is limited to the actual partition, queue, key, and consumer topology
- [ ] Backpressure limits in-flight work rather than hiding saturation with unbounded buffers
- [ ] Lag/backlog diagnosis includes ingress, egress, age, retries, and downstream latency
- [ ] Any destructive recovery action has an exact scope, expected effects, measurement, and approval

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** MESSAGE-QUEUES
- **Deliverable bucket:** `audits`
- **Mode:** conditional. When invoked to audit or review queue-related repository content, emit the
  full contract and write the deliverable to `docs/local/audits/message-queues/<YYYY-MM-DD>-<slug>.md`.
  Design, diagnosis, and recovery guidance remains conversational.
- **Severity scale:** `P0 | P1 | P2 | P3 | info`

## Sources

- [Apache Kafka documentation](https://kafka.apache.org/documentation/) - consumer groups, ordering,
  offsets, idempotent producers, and transactions
- [RabbitMQ acknowledgements and confirms](https://www.rabbitmq.com/docs/confirms) - manual acks,
  redelivery, publisher confirms, prefetch, and requeue behavior
- [RabbitMQ quorum queues](https://www.rabbitmq.com/docs/quorum-queues) - dead-lettering guarantees

## Rules

1. **Assume at-least-once delivery unless the complete boundary proves otherwise.** Consumers must
   tolerate duplicates; producer retries need stable message IDs.
2. **Acknowledge after the durable effect.** Auto-ack or early commit trades reliability for loss.
3. **Make retries bounded and observable.** Include jitter/delay where supported; route poison
   messages away from the hot path.
4. **Treat replay as a new execution.** It can recreate effects, so use idempotency and scope it.
5. **Measure age as well as count.** A small backlog containing old messages can be more urgent than
   a large fresh burst.
6. **Do not alter live broker state during diagnosis.** Read metrics, logs, and configuration first;
   request approval for offset resets, purges, requeues, topology edits, or production replay.
