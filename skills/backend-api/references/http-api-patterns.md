# HTTP API Patterns

Use this file when the main skill needs concrete API design rules without turning `SKILL.md`
into a full HTTP textbook.

## Resource Modeling

Prefer nouns and relationships:

| Goal | Prefer | Avoid |
|------|--------|-------|
| List users | `GET /users` | `GET /getUsers` |
| One user | `GET /users/{userId}` | `GET /user?id=123` |
| User sessions | `GET /users/{userId}/sessions` | `GET /sessions?userId=123` when nesting is clearer |
| Start workflow | `POST /orders/{orderId}/cancel` for explicit domain commands | Smuggling commands into vague updates |

Two decent patterns for commands:
- Treat the command as a subresource: `POST /orders/{orderId}/cancel`
- Model the resulting resource explicitly: `POST /refunds`

Pick one pattern and stay consistent.

## Method Semantics

| Method | Use for | Notes |
|--------|---------|-------|
| `GET` | Read | Safe and cacheable by default; no side effects |
| `POST` | Create or non-idempotent command | Use idempotency keys when retries matter |
| `PUT` | Full replacement | The client sends the full target state |
| `PATCH` | Partial update | Define patch semantics clearly; do not use as "misc update" |
| `DELETE` | Delete | Decide whether response is `204`, `200`, or async `202` |

Common status codes:

| Situation | Status |
|-----------|--------|
| Read success | `200` |
| Create success | `201` |
| Async accepted | `202` |
| Delete with no body | `204` |
| Validation failure | `400` or `422`, but pick one house style |
| Unauthenticated | `401` |
| Forbidden | `403` |
| Missing resource | `404` |
| Version or state conflict | `409` |
| Precondition failed | `412` |
| Too many requests | `429` |

Do not return `200` for everything because the framework made it easy.
If the service already chose `400` or `422` for validation errors, keep that convention unless
the task explicitly includes a broader migration.

## Versioning

Default rule: avoid breaking changes; version only when needed.

Path versioning is the clearest default for public APIs:

```text
/v1/users
/v1/orders/{orderId}
```

Use a new version when you must:
- Remove or rename fields clients depend on
- Change a field type or semantic meaning
- Rework auth or permission boundaries in a breaking way

Do not cut a new version for:
- Adding optional response fields
- Adding new endpoints
- Adding new enum values when the contract already documents extensibility

## OpenAPI Version Choice

The current OpenAPI Specification is `3.2.0`, but many framework-integrated docs and Swagger
toolchains still target `3.1.x` most comfortably.

Practical rule:
- Prefer `3.1` as the default authoring target unless the project's generators, validators,
  docs renderer, and gateway tooling are all confirmed to handle `3.2`
- Treat `3.2` as an opt-in upgrade, not as an automatic edit every time you touch an API spec

## Pagination

Use offset pagination only when all of these are true:
- The list is small or internal
- Stable ordering is easy
- Duplicate or skipped rows under concurrent writes are acceptable

Use cursor pagination when:
- The list can grow large
- New rows arrive often
- Users page through results in order

Cursor shape:

```text
GET /events?cursor=eyJjcmVhdGVkQXQiOiIyMDI2LTA0LTA2VDEwOjAwOjAwWiIsImlkIjoiZXZ0XzEyMyJ9&limit=50
```

Rules:
- Keep sort order stable
- Include tie-breakers in the cursor (`createdAt` + `id`, not just `createdAt`)
- Return pagination metadata that is consistent across list endpoints
- Keep list parameter names consistent across the service (`cursor`/`limit` or `page`/`perPage`, not both without a migration plan)

## Filtering and Sorting

Filters should map to domain language:

```text
GET /orders?status=paid&customerId=cus_123&createdAfter=2026-04-01T00:00:00Z
```

Sorting rules:
- Allow only documented sort fields
- Document default sort order
- Reject invalid sort fields instead of silently ignoring them

## Idempotency

Use explicit idempotency keys for operations that create external side effects:
- Payments
- Checkout or order creation
- Webhook handling
- Email or SMS sends
- Any endpoint likely to be retried by clients, workers, or proxies

Typical pattern:

```http
POST /payments
Idempotency-Key: 77a5e517-0b63-42c2-8fb7-d4df0f1e30e6
```

Rules:
- Scope the key to the caller and operation
- Store enough request fingerprint data to detect key reuse with different payloads
- Return the same semantic result for safe replays
- Expire old keys deliberately, not accidentally

## Problem Details

RFC 9457 gives a standard error shape:

```json
{
  "type": "https://api.example.com/problems/insufficient-balance",
  "title": "Insufficient balance",
  "status": 409,
  "detail": "Account acc_123 cannot fund order ord_456.",
  "instance": "/orders/ord_456/payments/pay_789"
}
```

Add stable extension fields when helpful:
- `code`
- `requestId`
- `fieldErrors`

Do not invent a new top-level error envelope for every layer of the service.
