# Brokered delivery semantics

- Define producer confirmation, broker durability, acknowledgement point, ordering scope, retention, and the permitted loss and duplicate window. Exactly-once claims need an explicit boundary; external effects need idempotency or a transactional outbox/inbox.
- Trace a message from publish through durable business effect and acknowledgement, including crashes after the effect, timeouts, malformed payloads, dependency outages, and retry exhaustion. Acknowledge after the durable effect and make redelivery safe.
- Bound in-flight work and retry transient failures with capped attempts and backoff. Send poison messages to an owned, monitored dead-letter destination with message ID, source, failure and attempt count; plan repair and replay.
- Limit ordering claims to the actual partition, key, queue, and consumer topology. Measure ingress, egress, backlog age, retries, dead letters and downstream latency before changing capacity.
- Offset resets, purges, requeues, and replay change delivery state: scope and rehearse the action, record rollback information, obtain authorization, and verify against a stop condition.
