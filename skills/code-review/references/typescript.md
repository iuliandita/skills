# TypeScript / JavaScript Bug Patterns

Bug patterns specific to TypeScript and JavaScript. These focus on correctness -- not style (see anti-slop) or security (see security-audit).

---

## Promise & Async Pitfalls

### Missing `await`

The most common async bug. A function returns a Promise but the caller forgets `await`, so it gets a Promise object instead of the resolved value.

**Detect:**
- Async function called without `await` in a non-fire-and-forget context
- Promise assigned to a variable but never awaited
- `return asyncFn()` in a non-async function (returns the Promise, not the value)
- Conditional `await` (`if (x) await fn()` -- the else branch doesn't await)

**Example:**
```typescript
// bug: returns Promise<boolean>, not boolean
function isValid(id: string) {
  return checkDatabase(id); // missing await, function isn't async
}

if (isValid("123")) { // always truthy -- it's a Promise object
  proceed();
}
```

### Unhandled Promise Rejections

Promises that reject with no `.catch()` or try/catch around `await`.

**Detect:**
- `Promise.all()` without wrapping try/catch -- one rejection kills all, but remaining promises still run
- Fire-and-forget async calls without `.catch()` (`doSomething()` without await or catch)
- `async void` functions (errors can't be caught by the caller)
- `.then()` chains without a terminal `.catch()`
- Event handlers that are async but don't handle their own errors

**Example:**
```typescript
// bug: if any fetch fails, Promise.all rejects but all fetches still run
const results = await Promise.all(urls.map(url => fetch(url)));

// fix: handle individual failures
const results = await Promise.allSettled(urls.map(url => fetch(url)));
```

### `async void`

Async functions that return void can't have their errors caught by the caller.

**Detect:**
- Event handlers declared as `async` without internal error handling
- Callbacks passed to `.forEach()`, `.map()`, event listeners that are `async`
- `setTimeout(async () => { ... })` -- the async return value is ignored

**Example:**
```typescript
// bug: errors vanish silently
button.addEventListener('click', async () => {
  await saveData(); // if this throws, nothing catches it
});

// fix: handle errors internally
button.addEventListener('click', async () => {
  try {
    await saveData();
  } catch (err) {
    showError(err);
  }
});
```

---

## Type System Gaps

### Unsafe Type Assertions

`as` casts bypass runtime safety. The type system says it's fine, but the runtime disagrees.

**Detect:**
- `as unknown as T` double-cast (almost always hiding a real type mismatch)
- `as any` to silence errors (masks the actual bug)
- `as T` on external data (API responses, parsed JSON, user input) without validation
- Non-null assertion `!` on values that genuinely can be null

**Example:**
```typescript
// bug: API might not return this shape at all
const user = (await res.json()) as User;
console.log(user.name.toUpperCase()); // crash if name is undefined

// fix: validate the shape
const data = await res.json();
const user = userSchema.parse(data); // zod, valibot, etc.
```

### Discriminated Union Exhaustiveness

Switch/if-else on discriminated unions that don't handle all cases.

**Detect:**
- Switch on `type` field without `default` that does `assertNever`
- New union member added but not all handlers updated
- `if (x.type === 'a') ... else if (x.type === 'b') ...` without else

**Example:**
```typescript
type Action = { type: 'create' } | { type: 'update' } | { type: 'delete' };

function handle(action: Action) {
  switch (action.type) {
    case 'create': return create();
    case 'update': return update();
    // bug: 'delete' falls through silently
  }
}
```

---

## Closure & Scope Traps

### Stale Closures

Closures capturing variables that change after the closure is created.

**Detect:**
- `var` or `let` in a loop with async operations or callbacks
- React `useEffect` / `useCallback` with missing dependency array entries
- `setTimeout` / `setInterval` callbacks using variables that update
- Event handlers registered once but reading changing state

**Example:**
```typescript
// bug: all callbacks log the final value of i
for (var i = 0; i < 5; i++) {
  setTimeout(() => console.log(i), 100); // prints 5, 5, 5, 5, 5
}

// fix: use let (block-scoped) or capture
for (let i = 0; i < 5; i++) {
  setTimeout(() => console.log(i), 100); // prints 0, 1, 2, 3, 4
}
```

### Captured Mutable References

Closures that capture an object/array reference and later see mutations they didn't expect.

**Detect:**
- Async callbacks closing over an array that gets `.push()`ed to between await points
- State objects mutated after being captured in a closure
- Config objects read in a callback but mutated elsewhere

**Example:**
```typescript
// bug: items array is mutated between await points
const items: string[] = [];
for (const id of ids) {
  items.push(id);
  scheduleWork(async () => {
    // by the time this runs, items has ALL ids, not just up to this point
    await processItems([...items]);
  });
}

// fix: snapshot the array at capture time
for (const id of ids) {
  items.push(id);
  const snapshot = [...items];
  scheduleWork(async () => {
    await processItems(snapshot);
  });
}
```

**Fix:** Snapshot mutable state at the point of capture. Use spread, `structuredClone()`, or `Array.from()` to create an independent copy.

---

## React-Specific Bugs

### Missing / Wrong Dependency Arrays

`useEffect`, `useMemo`, `useCallback` with incorrect dependencies.

**Detect:**
- Empty `[]` dependency array but effect body reads props or state
- Object/array literals in dependency arrays (new reference every render, infinite loop)
- Missing dependencies that cause stale data
- Including `setState` functions (stable, don't need to be deps -- but raw state does)

**Example:**
```typescript
// bug: effect runs once, but reads `userId` which changes
useEffect(() => {
  fetchUser(userId).then(setUser);
}, []); // should be [userId]

// bug: infinite loop -- {} is a new object every render
useEffect(() => { ... }, [{ key: value }]);
```

### State Updates During Render

Setting state during the render phase causes infinite re-renders.

**Detect:**
- `setState()` called directly in the component body (not in an effect or handler)
- Derived state computed with `useState` + `useEffect` when `useMemo` would work
- State updates in `useMemo` (side effect in a pure computation)

### Effect Cleanup Leaks

Effects that subscribe/listen but don't clean up.

**Detect:**
- `useEffect` that adds event listeners without returning a cleanup function
- `useEffect` that starts timers/intervals without clearing them
- `useEffect` that creates subscriptions (WebSocket, observable) without unsubscribing
- Async operations in effects that update state after unmount

**Example:**
```typescript
// bug: memory leak -- listener never removed
useEffect(() => {
  window.addEventListener('resize', handleResize);
}, []);

// fix: return cleanup
useEffect(() => {
  window.addEventListener('resize', handleResize);
  return () => window.removeEventListener('resize', handleResize);
}, []);
```

---

## Node.js-Specific Bugs

### Stream Error Handling

Streams that don't have `error` event handlers crash the process.

**Detect:**
- `fs.createReadStream()` / `createWriteStream()` without `.on('error', ...)`
- Piped streams without error handling on each stream in the pipe
- Transform streams that don't forward errors
- HTTP request/response streams without error handlers

**Example:**
```typescript
// bug: crashes process if file doesn't exist
const stream = fs.createReadStream('/maybe/missing');
stream.pipe(transform).pipe(output);

// fix: handle errors on every stream
stream.on('error', handleErr);
transform.on('error', handleErr);
output.on('error', handleErr);
```

### EventEmitter Gotchas

- Missing `error` event handler on EventEmitter (throws and crashes if error is emitted)
- `once` vs `on` confusion (registering a one-time handler when persistent is needed)
- Max listeners warning (adding listeners in a loop without removing them)

### Process Exit Edge Cases

- `process.exit()` called before async operations complete (data loss)
- Unhandled rejection handler missing in Node 15+ (crashes the process)
- Signal handlers (`SIGTERM`, `SIGINT`) that don't clean up before exiting

---

## Common JavaScript Gotchas

### Equality and Coercion

- `==` instead of `===` (type coercion surprises: `"" == false`, `0 == ""`, `null == undefined`)
- `typeof null === 'object'` (historical bug, still trips people up)
- `NaN !== NaN` (use `Number.isNaN()`, not `=== NaN`)
- Array/object equality by reference (`[1,2] !== [1,2]`)

### `this` Binding

- Method passed as callback loses `this` context (`arr.forEach(obj.method)`)
- Arrow functions in class properties vs prototype methods (memory implications)
- `this` in nested functions/callbacks (undefined in strict mode)

### Numeric Precision

- `0.1 + 0.2 !== 0.3` (IEEE 754)
- `parseInt("08")` without radix (legacy octal parsing in old engines)
- `Number.MAX_SAFE_INTEGER` overflow in ID handling (use BigInt or string IDs)
- `Date.parse()` returning NaN for valid-looking date strings (inconsistent across engines)
