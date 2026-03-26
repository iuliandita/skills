# Universal Review Patterns

Use these cross-language categories before diving into language-specific checks.

## 1. Logic Errors

The most dangerous category: code that runs without errors but produces wrong results.

Detect:
- off-by-one errors in loops, slices, ranges, and pagination
- wrong comparison operators or inverted conditions
- missing `break` or `return` in switch or match logic
- short-circuit evaluation surprises with side effects
- integer overflow or underflow, float equality misuse
- regex or string comparisons that do not do what the author expects

Fix:
- trace the logic with concrete values
- write the truth table if the condition is complex

## 2. Null or Undefined Hazards

Code paths where values can be absent but are treated as guaranteed.

Detect:
- property or index access on maybe-null values
- map or object lookups without existence checks
- destructuring from partially populated inputs
- function results, DB rows, or API payloads assumed present
- env vars assumed to exist

Fix:
- handle absence explicitly: fail fast, return a real default, or propagate it honestly

## 3. Error-Handling Gaps

Look for missing handling where failure is normal, not exceptional.

Detect:
- async or network operations that assume success
- parsing that can throw without guards
- catch blocks that swallow context
- cleanup paths that do not run on error
- wrong exception types handled or missing propagation

Fix:
- handle errors at the right boundary
- add context when rethrowing

## 4. Race Conditions and State

Bugs that appear only under timing, load, or ordering pressure.

Detect:
- TOCTOU patterns
- shared mutable state without synchronization
- ordering assumptions in async or event-driven code
- mutation during iteration
- stale closures, non-transactional read-then-write flows

Fix:
- make operations atomic or remove shared mutable state

## 5. Resource Management

Resources acquired but not reliably released.

Detect:
- files, sockets, DB connections, temp files, locks, timers, listeners, child processes left behind

Fix:
- keep acquire and release adjacent with `finally`, `with`, `defer`, `using`, or the language equivalent

## 6. Edge Cases and Boundaries

Valid inputs that still break the code.

Detect:
- empty, zero, negative, huge, deeply nested, Unicode, timezone, locale, and path edge cases
- last-page pagination bugs
- concurrent modification during iteration

Fix:
- test empty, zero, one, many, and max-size cases explicitly

## 7. API Contract Issues

Code that breaks when assumptions about other code or external systems drift.

Detect:
- caller and callee signature mismatches
- unchecked external payload shapes
- implicit ordering dependencies
- magic strings or config values used inconsistently
- schema assumptions not enforced anywhere

Fix:
- validate at boundaries
- encode assumptions in types or explicit checks

## 8. Performance Traps

Only the ones that cause incidents, not style-level micro-optimizations.

Detect:
- N+1 queries
- unbounded growth
- blocking the main thread or event loop
- no pagination on potentially huge results
- quadratic behavior on user-controlled input
- loading everything into memory when streaming would work

Fix:
- change the algorithm, batching, indexing, or data flow

## 9. Convention Violations That Matter

Only project conventions that affect correctness belong here.

Detect:
- skipped required transactions, middleware, lifecycle hooks, or test coverage rules
- environment-specific rules that prevent runtime breakage

Do not flag:
- naming, formatting, import order, or generic style inconsistency

Fix:
- follow the established correctness rule or explain why this case is exempt

## 10. Test Correctness

Broken tests create false confidence.

Detect:
- tests that would still pass if the implementation were wrong or deleted
- wrong or missing assertions
- flaky timing or ordering
- mocks replacing so much behavior that nothing real is tested
- setup that does not reflect production behavior

Fix:
- make the test fail when the described behavior breaks
