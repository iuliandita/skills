# Brokered delivery semantics

- Define producer confirmation, broker durability, acknowledgement point, ordering scope, retention, and the permitted loss and duplicate window. Exactly-once claims need an explicit boundary; external effects need idempotency or a transactional outbox/inbox.
- Trace a message from publish through durable business effect and acknowledgement, including crashes after the effect, timeouts, malformed payloads, dependency outages, and retry exhaustion. Acknowledge after the durable effect and make redelivery safe.
- Bound in-flight work and retry transient failures with capped attempts and backoff. Send poison messages to an owned, monitored dead-letter destination with message ID, source, failure and attempt count; plan repair and replay.
- Limit ordering claims to the actual partition, key, queue, and consumer topology. Measure ingress, egress, backlog age, retries, dead letters and downstream latency before changing capacity.
- Offset resets, purges, requeues, and replay change delivery state: scope and rehearse the action, record rollback information, obtain authorization, and verify against a stop condition.

## Idempotency and retries

- Define idempotency for writes that clients or gateways may retry
- Use explicit idempotency keys for payment-like or request-replay-prone operations
- Distinguish "request accepted" from "side effect completed" when async workflows exist

Use the same transaction protocol in Express/NestJS and FastAPI; a cache get/write/set
sequence is not atomic:

1. Authenticate and authorize the operation. Bound the header length and scope the key to
   the caller or tenant plus operation; hash the normalized request into a fingerprint.
2. Atomically reserve that scoped key with a unique database constraint. For an existing
   record, reject a different fingerprint; report in-progress work without executing it again.
   Replay a completed authorized outcome only for the matching caller and fingerprint.
3. Commit the business mutation and completed response record in the same transaction.
   For external effects, use a transactional outbox and the provider's idempotency facility;
   a database rollback cannot undo an already sent payment or message.
4. Retain outcomes for the documented retry window. Recover interrupted reservations through
   a defined state transition, never by blindly executing the effect again. Test concurrent
   duplicates, two callers sharing a key, body mismatch, and crashes between effect and reply.

Cursor pagination response envelope:
```json
{
  "data": [...],
  "next_cursor": "eyJpZCI6MTIzfQ",
  "has_more": true
}
```
Decode the cursor server-side (`WHERE id > :cursor_id ORDER BY id LIMIT :limit`). Never expose raw DB offsets or row numbers in the cursor.

Opaque cursor encode/decode (FastAPI, HMAC-signed to prevent client tampering):
```python
import base64, hmac, hashlib, json, os

SECRET = os.environ["CURSOR_SECRET"].encode()

def encode_cursor(payload: dict) -> str:
    body = base64.urlsafe_b64encode(json.dumps(payload, separators=(",", ":")).encode()).rstrip(b"=")
    sig = base64.urlsafe_b64encode(hmac.new(SECRET, body, hashlib.sha256).digest()[:8]).rstrip(b"=")
    return f"{body.decode()}.{sig.decode()}"

def decode_cursor(token: str) -> dict:
    body, sig = token.split(".", 1)
    expected = base64.urlsafe_b64encode(hmac.new(SECRET, body.encode(), hashlib.sha256).digest()[:8]).rstrip(b"=").decode()
    if not hmac.compare_digest(sig, expected):
        raise ValueError("invalid cursor")
    return json.loads(base64.urlsafe_b64decode(body + "=="))
```
Clients treat `next_cursor` as opaque; the server controls shape and can change it without a breaking contract.
