# Java Bug Patterns

Bug patterns specific to Java, with focus on Quarkus and Spring Boot. Focused on correctness -- not style (see anti-slop) or security (see security-audit).

---

## Quarkus-Specific

### CDI Scope Bugs

**Detect:**
- Mutable fields in `@ApplicationScoped` beans without synchronization (shared across ALL requests -- race condition)
- `@RequestScoped` bean injected into reactive pipelines (`Uni`/`Multi`) -- request context may be gone when operators execute on different threads
- Subclass of a scoped bean without its own scope annotation -- scope doesn't inherit, defaults to `@Dependent`

**Example:**
```java
// bug: request context gone when Uni operator executes
@ApplicationScoped
public class OrderService {
    @Inject SecurityIdentity identity; // @RequestScoped

    public Uni<Order> create(Order order) {
        return Uni.createFrom().item(order)
            .onItem().transformToUni(o -> {
                o.setCreatedBy(identity.getPrincipal().getName()); // NPE or ContextNotActiveException
                return persist(o);
            });
    }
}

// fix: extract scoped data before entering reactive pipeline
public Uni<Order> create(Order order) {
    String username = identity.getPrincipal().getName(); // capture here
    return Uni.createFrom().item(order)
        .onItem().transformToUni(o -> {
            o.setCreatedBy(username); // safe -- plain String
            return persist(o);
        });
}
```

### Mutiny Pitfalls

**Detect:**
- `Uni`/`Multi` returned but never subscribed (method returns `void` instead of `Uni<Void>` -- pipeline never executes)
- `Multi` stream killed by single item failure without per-item recovery
- Blocking calls inside `Uni`/`Multi` operators (JDBC, `Thread.sleep()`, synchronized)

### Native Image Gotchas

**Detect:**
- Classes used in Jackson serialization without `@RegisterForReflection` (works in JVM, fails in native)
- `Object` or generic types in DTOs forcing reflection-based serialization
- Static initializers that start threads or open connections (captured at build time)
- `Thread.currentThread().getContextClassLoader()` returning null in native

**Fix:** Register reflection targets. Defer initialization to `@Observes StartupEvent`. Use concrete types in DTOs.

### Config & Dev Services

**Detect:**
- `quarkus.hibernate-orm.database.generation=drop-and-create` without `%dev.` profile prefix (drops production database)
- Property name mismatches in SmallRye config (dash vs dot: `key-location` vs `key.location`)
- REST client `@Provider` filters with `@Inject` fields -- CDI injection is null in JAX-RS provider context
- `Optional<String>` as `@HeaderParam` sends literal `"Optional[value]"` (toString output)

---

## Spring Boot

### @Transactional Proxy Traps

The #1 source of Spring bugs. `@Transactional` works through CGLIB proxies -- anything that bypasses the proxy silently loses the transaction.

**Detect:**
- Self-invocation: method in the same bean calling another `@Transactional` method directly (bypasses proxy, no transaction)
- `@Transactional` on non-public methods (silently ignored -- proxy can't intercept)
- `@Transactional` on `final` class or method (CGLIB can't subclass)
- Checked exception thrown without `rollbackFor` (Spring only auto-rolls-back on unchecked exceptions)
- `@Transactional` called from `@PostConstruct` (proxy not fully initialized)
- Transaction-bound work spawned into `CompletableFuture.runAsync()` (different thread, different EntityManager, no transaction)

**Example:**
```java
// bug: self-invocation bypasses proxy -- NO transaction on saveOrder
@Service
public class OrderService {
    public void placeOrder(Order order) {
        validate(order);
        saveOrder(order); // direct call, not through proxy
    }

    @Transactional
    public void saveOrder(Order order) {
        orderRepo.save(order);
        auditRepo.save(new AuditLog(order)); // no rollback if this fails
    }
}
```

**Fix:** Extract to a separate bean, use `TransactionTemplate`, or inject self.

### Spring Security & Filters

**Detect:**
- Multiple `SecurityFilterChain` beans without `@Order` and `securityMatcher()` -- first registered wins, others are dead code
- Custom `Filter` missing `chain.doFilter(req, res)` on the happy path (returns blank response for all requests)
- `@PermitAll` or CSRF disabled "for testing" left in production config

### WebFlux / Reactor

**Detect:**
- JDBC/blocking I/O inside `Mono`/`Flux` operators without `.subscribeOn(Schedulers.boundedElastic())`
- ThreadLocal-based MDC/trace context lost across operator boundaries (different thread)
- Multiple active Spring profiles where "last wins" ordering is misunderstood

---

## General Java

### Optional Misuse

**Detect:**
- `Optional.of(x)` where `x` can be null (throws NPE -- use `ofNullable`)
- `.get()` without `.isPresent()` check (throws `NoSuchElementException`)
- `Optional` as class field or method parameter (it's for return types only, not serializable)

### Stream API Pitfalls

**Detect:**
- Stream variable used in two terminal operations (throws `IllegalStateException: stream already closed`)
- Lazy evaluation escaping try-catch (stream constructed in try block, consumed outside -- exceptions aren't caught)
- Side effects in `map()`/`filter()` with `parallelStream()` (race condition on shared mutable state)

**Example:**
```java
// bug: exception escapes try-catch due to lazy evaluation
Stream<Config> configs;
try {
    configs = files.stream().map(this::parseConfig); // lazy -- nothing runs yet
} catch (ConfigException e) {
    return defaults; // never catches anything
}
return configs.collect(Collectors.toList()); // exception thrown HERE, uncaught
```

### Concurrency Bugs

**Detect:**
- `if (!map.containsKey(k)) map.put(k, v)` on `ConcurrentHashMap` (check-then-act race -- use `computeIfAbsent()`)
- `ConcurrentHashMap.size()` used for business logic (approximate under concurrency)
- Mutable objects as `HashMap` keys where `hashCode()` depends on mutable fields (entry "lost" after mutation)
- `equals()` overridden without `hashCode()` (breaks `HashSet`, `HashMap`)

### Error Handling

**Detect:**
- Checked exception caught and swallowed in lambdas (returning null, poisoning downstream with NPEs)
- Catch block that logs AND rethrows (same stack trace logged 2-5x up the call chain -- log OR throw, not both)
- Try-with-resources with chained constructors (`new BufferedReader(new FileReader(f))` -- if outer constructor throws, inner resource leaks)
- `raise NewException("msg")` inside catch without chaining original (`throw new X("msg", cause)`)

### equals/hashCode Contract

**Detect:**
- Override one without the other (breaks HashMap/HashSet contracts)
- Mutable fields in `hashCode()` on objects used as map keys
- `equals()` comparing with `instanceof` but class is not `final` (subclass symmetry violation)

**Fix:** Use `record` for value types (auto-generates both correctly). For classes, use IDE generation or `Objects.hash()`.

---

## Modern Java (17+)

### Virtual Threads (Project Loom)

**Detect:**
- `synchronized` blocks in code called from virtual threads -- pins the carrier thread, defeating scalability (use `ReentrantLock` instead)
- `ThreadLocal` with virtual threads -- 1M virtual threads = 1M ThreadLocal instances (use `ScopedValue` in Java 25+)
- Assuming virtual threads increase DB throughput (HikariCP has 10 connections regardless -- 9,990 virtual threads just block waiting)
- `StructuredTaskScope` without try-with-resources (thread leak on exception)

**Fix:** Detect pinning with `-Djdk.tracePinnedThreads=full`. Note: Java 24+ resolves `synchronized` pinning, but JNI pinning remains.

### Pattern Matching & Sealed Classes

**Detect:**
- Switch over sealed type without `default` -- new permitted subclass in dependency update causes `IncompatibleClassChangeError` at runtime
- Pattern-matching switch without `case null` -- NPE if input is null (no null case, no default)

**Fix:** For sealed types you own: compiler catches missing cases on recompilation. For sealed types in external deps: add defensive `default`.

### Records

**Detect:**
- Attempting inheritance with records (`record B extends A` -- compile error, records are final)
- Custom serialization hooks (`writeObject`/`readObject`) on records -- silently ignored
- Records with mutable field types (the reference is final, but the object it points to can be mutated)

---

## Build & Dependencies

**Detect:**
- Manual dependency version conflicting with Quarkus/Spring BOM (transitive dep brings different version, runtime `NoSuchMethodError`)
- `quarkus update` silently removing intentionally pinned dependency versions
- Gradle `strictly` constraint fighting with BOM-managed versions
- Duplicate classes on classpath (`NoSuchMethodError`, `ClassCastException` at runtime, not in IDE)

**Fix:** Run `mvn dependency:tree -Dverbose` or Gradle `dependencies` task after any dependency change. Exclude conflicting transitives.

---

## AI-Generated Java Code

AI tools commonly get these wrong in Java:

- **Framework confusion**: `@Autowired` in Quarkus code (should be `@Inject`), Spring's `@Transactional` import in CDI context
- **Overcomplicated generics**: `<T extends Comparable<? super T>, R extends Collection<? extends T>>` when `List<String>` would do
- **Unnecessary abstractions**: Interface + Impl + Factory for a single-implementation service
- **Hallucinated dependencies**: artifact IDs that don't exist on Maven Central
- **Concurrency blindness**: mutable shared state in `@ApplicationScoped` beans without atomics (2x more likely in AI code than human code)
- **Security shortcuts**: disabling CSRF, `@PermitAll`, hardcoded credentials (1.5-2x more likely in AI code)
- **Missing edge cases**: `Optional.get()` without check, empty list not handled, division by zero

**Rule of thumb:** AI-generated Java code that touches threading, transactions, or security needs extra scrutiny.
