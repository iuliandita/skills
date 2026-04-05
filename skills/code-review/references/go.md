# Go Bug Patterns

Bug patterns specific to Go. Focused on correctness -- not style (see anti-slop) or security (see security-audit).

---

## Goroutine Lifecycle & Leak Detection

### Goroutine Leaks

Goroutines that block forever are memory leaks. Unlike threads, leaked goroutines are invisible to the runtime -- no finalizer, no timeout, no warning.

**Detect:**
- Goroutine sends to a channel with no receiver (or receiver already exited)
- Goroutine receives from a channel that is never closed and never sent to again
- Goroutine blocked on a mutex held by code that will never release it
- `go func()` launched without any termination signal (no context, no done channel, no timeout)
- Server handler spawns goroutines that outlive the request without lifecycle management

**Example:**
```go
// bug: goroutine leaks if ctx is canceled before ch receives
func fetch(ctx context.Context) error {
    ch := make(chan result)
    go func() {
        ch <- doExpensiveWork() // blocks forever if nobody reads ch
    }()
    select {
    case r := <-ch:
        return r.err
    case <-ctx.Done():
        return ctx.Err() // goroutine still blocked on ch <- ...
    }
}

// fix: use buffered channel so send never blocks
func fetch(ctx context.Context) error {
    ch := make(chan result, 1) // buffer of 1
    go func() {
        ch <- doExpensiveWork() // completes even if nobody reads
    }()
    select {
    case r := <-ch:
        return r.err
    case <-ctx.Done():
        return ctx.Err()
    }
}
```

### Missing WaitGroup / errgroup

**Detect:**
- Goroutines launched in a loop with no `sync.WaitGroup` or `errgroup.Group` to wait for completion
- `wg.Add()` called inside the goroutine instead of before `go func()` (race condition -- parent may call `wg.Wait()` before child calls `wg.Add()`)
- `errgroup.Group` used without checking the error returned by `g.Wait()`

---

## Nil Interface vs Nil Pointer

An interface value is nil only when both its type and value are nil. An interface holding a typed nil pointer is NOT nil.

**Detect:**
- Function returns a concrete error type as `nil` but the caller checks `err != nil` on the interface
- `var err *MyError; return err` where return type is `error` -- caller sees non-nil error
- Type-switching on an interface that might hold a typed nil

**Example:**
```go
// bug: returns non-nil error even on success
func validate(s string) error {
    var err *ValidationError
    if s == "" {
        err = &ValidationError{msg: "empty"}
    }
    return err // typed nil -- interface{type: *ValidationError, value: nil} != nil
}

// fix: return nil explicitly
func validate(s string) error {
    if s == "" {
        return &ValidationError{msg: "empty"}
    }
    return nil // untyped nil -- interface is truly nil
}
```

**Related trap:** `reflect.DeepEqual(nil, (*T)(nil))` returns `false`. Comparing interface nil to typed nil with `==` also returns `false`.

---

## Defer Ordering & Closure Capture

### Defer Executes LIFO

Defers run in last-in-first-out order. This matters when operations have dependencies (e.g., flush before close).

**Detect:**
- `defer f.Close()` before `defer writer.Flush()` -- file closes before flush, data lost
- Deferred unlock before deferred lock acquisition in complex flows
- Multiple defers on the same resource in non-obvious order

### Defer Captures by Reference

Deferred function arguments are evaluated at the `defer` statement. But closures capture variables by reference -- the value at execution time (when the function returns), not declaration time.

**Detect:**
- `defer fmt.Println(x)` -- `x` evaluated NOW (at defer statement)
- `defer func() { fmt.Println(x) }()` -- `x` evaluated LATER (at return)
- Loop with `defer` inside -- defers accumulate until function returns, not until loop iteration ends

**Example:**
```go
// bug: all defers print the final value of i
for i := 0; i < 5; i++ {
    defer func() { fmt.Println(i) }() // prints 5, 5, 5, 5, 5
}

// fix: pass as argument to capture current value
for i := 0; i < 5; i++ {
    defer func(n int) { fmt.Println(n) }(i) // prints 4, 3, 2, 1, 0
}
```

### Defer in Loops

**Detect:**
- `defer file.Close()` inside a loop -- files stay open until the enclosing function returns, not until the next iteration. For long loops this exhausts file descriptors.
- Fix: extract to a helper function so defer runs per iteration, or close explicitly.

---

## Channel Patterns & Deadlock

### Unbuffered Channel Deadlocks

An unbuffered channel blocks the sender until a receiver is ready, and vice versa. Single-goroutine send-then-receive deadlocks.

**Detect:**
- `ch <- val` followed by `<-ch` in the same goroutine (deadlock)
- All receivers exit before senders finish (sender blocks forever)
- `select` with no `default` case where all channels might be blocked

### Closing Channels

**Detect:**
- Closing a channel from the receiver side (only senders should close)
- Closing a channel more than once (runtime panic)
- Sending on a closed channel (runtime panic)
- Not checking the `ok` value from `v, ok := <-ch` (reads zero value from closed channel without noticing)
- Closing a nil channel (runtime panic)

**Example:**
```go
// bug: range loops forever if ch is never closed
func consume(ch chan int) {
    for v := range ch { // blocks forever after last send
        process(v)
    }
}

// fix: sender must close the channel
func produce(ch chan int) {
    defer close(ch) // signals consumers that no more values are coming
    for _, v := range items {
        ch <- v
    }
}
```

### Select Statement Pitfalls

**Detect:**
- `select` with both `case <-ctx.Done()` and a channel operation -- Go picks randomly when both are ready, so a cancel might not be noticed immediately
- `for-select` loop without a return/break on the done case (loop continues after cancel)
- `time.After()` inside a `for-select` loop -- creates a new timer every iteration, leaking until GC

```go
// bug: new timer allocated every iteration, old ones leak until they fire
for {
    select {
    case msg := <-ch:
        process(msg)
    case <-time.After(5 * time.Second): // leak!
        return
    }
}

// fix: reuse a ticker or reset a timer
timer := time.NewTimer(5 * time.Second)
defer timer.Stop()
for {
    select {
    case msg := <-ch:
        if !timer.Stop() {
            <-timer.C
        }
        timer.Reset(5 * time.Second)
        process(msg)
    case <-timer.C:
        return
    }
}
```

---

## Error Wrapping & Sentinel Errors

### Wrapping Breaks `errors.Is()` / `errors.As()`

**Detect:**
- `fmt.Errorf("failed: %s", err)` -- wraps the message but loses the error chain. Use `%w` to preserve it.
- `fmt.Errorf("failed: %w %w", err1, err2)` -- multiple `%w` is valid since Go 1.20 but callers must handle multi-error unwrapping
- Custom error types that implement `Error()` but not `Unwrap()` -- breaks `errors.Is()` and `errors.As()` for wrapped errors

**Example:**
```go
// bug: sentinel error is lost, errors.Is(err, ErrNotFound) returns false
if err != nil {
    return fmt.Errorf("lookup failed: %s", err) // %s = string only
}

// fix: use %w to preserve the chain
if err != nil {
    return fmt.Errorf("lookup failed: %w", err) // %w = wraps error
}
```

### Sentinel Error Comparison

**Detect:**
- `err == ErrFoo` instead of `errors.Is(err, ErrFoo)` -- breaks when errors are wrapped
- `err.(*MyError)` type assertion instead of `errors.As(err, &target)` -- same problem
- Sentinel errors defined as `var` instead of via `errors.New()` (mutable -- another package can overwrite)

---

## Context Cancellation Patterns

### Leaked Contexts

**Detect:**
- `context.WithCancel()` or `context.WithTimeout()` where the cancel function is never called (resource leak in the context tree)
- `defer cancel()` missing after `ctx, cancel := context.WithCancel(parent)`
- Passing `context.Background()` when a request-scoped context is available (ignores cancellation)

**Example:**
```go
// bug: cancel never called, context leaks
func process() error {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    // missing: defer cancel()
    return doWork(ctx)
}

// fix: always defer cancel
func process() error {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    return doWork(ctx)
}
```

### Context Value Anti-Patterns

**Detect:**
- Using `context.WithValue()` for data that should be function parameters (contexts are for request-scoped cross-cutting concerns, not dependency injection)
- String keys for context values (use unexported typed keys to avoid collisions)
- Storing mutable data in context values (contexts are meant to be immutable)

---

## Data Races & Shared State

### Common Race Conditions

**Detect:**
- Shared map accessed from multiple goroutines without `sync.Mutex` or `sync.Map` (concurrent map writes panic since Go 1.6)
- Shared slice appended to from multiple goroutines (append is not atomic -- can corrupt the slice header)
- Read-modify-write on shared variables without synchronization (`count++` is not atomic)
- `go test -race` not in CI pipeline (races only detected when tests exercise concurrent paths)

**Example:**
```go
// bug: concurrent map writes cause fatal panic
func handler(w http.ResponseWriter, r *http.Request) {
    cache[r.URL.Path] = time.Now() // panic: concurrent map writes
}

// fix: use sync.Mutex or sync.Map
var mu sync.Mutex
func handler(w http.ResponseWriter, r *http.Request) {
    mu.Lock()
    cache[r.URL.Path] = time.Now()
    mu.Unlock()
}
```

### Mutex Pitfalls

**Detect:**
- Copying a `sync.Mutex` (or any sync type) -- the copy shares no state with the original. Pass by pointer.
- `Lock()` without corresponding `Unlock()` on every code path (especially early returns)
- Nested locks in inconsistent order across functions (deadlock)
- Using `defer mu.Unlock()` in a long function where the critical section is only a few lines (holds lock too long)

---

## Loop Variable Capture (Pre-Go 1.22)

Go 1.22 changed loop variable semantics -- each iteration gets a new variable. For Go < 1.22, the classic closure capture bug applies.

**Detect:**
- Check `go.mod` for Go version. If `go 1.21` or earlier:
  - `go func() { use(v) }()` inside a `for _, v := range` loop -- all goroutines share the same `v`
  - `&v` taken inside a loop -- all pointers point to the same variable
- For Go >= 1.22: this class of bug is fixed by the compiler. Skip this check.

---

## Struct & Interface Gotchas

### Unkeyed Struct Literals

**Detect:**
- `MyStruct{val1, val2, val3}` -- positional fields break when struct fields are reordered or new fields are added. Use keyed literals: `MyStruct{Name: val1, Age: val2}`.

### Method Set Rules (Pointer vs Value Receivers)

**Detect:**
- Value of type `T` stored in an interface when the method set requires `*T` (compile error for interfaces, but subtle when embedding)
- Mixing pointer and value receivers on the same type without understanding that only `*T` satisfies interfaces requiring pointer-receiver methods
