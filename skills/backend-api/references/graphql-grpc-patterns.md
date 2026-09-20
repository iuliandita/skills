# GraphQL and gRPC Boundary Patterns

Use this reference only when the task includes GraphQL or gRPC. REST/HTTP remains the default focus
of **backend-api**; do not force a protocol migration.

## GraphQL

- Design the schema around stable domain concepts, then keep resolver authorization at the business
  boundary. A type or field being visible is not permission to return every object's data.
- Define pagination consistently, bound query depth/complexity and result size, and address N+1
  resolution with batching or request-scoped loading. Record how client-controlled queries are
  limited before enabling introspection or arbitrary expensive traversal in a public endpoint.
- Treat schema evolution as additive: deprecate fields with a migration path before removal. Keep
  errors deliberate: transport/protocol errors and domain errors should be distinguishable to clients.
- Federation needs explicit ownership, composition checks, entity keys, and an agreed migration plan;
  do not introduce it merely to split a small schema.

## gRPC

- Treat `.proto` files and generated code as public contracts. Prefer additive fields and RPCs;
  do not reuse field numbers, change wire types, or remove fields without a compatibility plan.
- Set explicit deadlines. Propagate cancellation to downstream work and make retries safe for the
  method's effect; retry policy does not make a non-idempotent write idempotent.
- Choose unary, server-streaming, client-streaming, or bidi streaming from the communication pattern.
  Bound messages, flow control, concurrency, and stream lifetime; define resume/reconnect behavior.
- Return canonical status codes with typed details where useful. Apply authentication and authorization
  at the service/method boundary, then enforce resource ownership in business logic.

## Validation

- For GraphQL, test authorization, field-level errors, pagination, query limits, resolver fan-out,
  and schema compatibility.
- For gRPC, test generated client/server compatibility, deadlines/cancellation, retry idempotency,
  status mapping, and streaming flow control under a bounded workload.

## Primary documentation

- [GraphQL best practices](https://graphql.org/learn/best-practices/)
- [gRPC deadlines](https://grpc.io/docs/guides/deadlines/)
- [gRPC retry](https://grpc.io/docs/guides/retry/)
