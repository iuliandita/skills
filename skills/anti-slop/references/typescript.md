# TypeScript / JavaScript Slop Patterns

## Type Abuse (Noise)

TypeScript's inference is good. Fighting it with redundant annotations is noise.

**Detect:**
- Explicit types on variables where inference handles it: `const name: string = 'hello'`
- `any` used to bypass type errors instead of fixing the actual type
- `catch (error: any)` instead of `catch (error: unknown)` with narrowing
- Utility type gymnastics that a simpler type would replace
- Interfaces with a single implementation and no plans for more
- Duplicated type definitions across files instead of importing from one source
- Enums where const objects or union types would be simpler and tree-shake better
- `as` casts to force types instead of fixing the actual data flow
- `Partial<T>` on everything instead of defining what's actually optional

**Fix:** Remove redundant annotations. Replace `any` with `unknown` or proper types. Consolidate duplicate types. Prefer `type Foo = 'a' | 'b'` over `enum Foo { A = 'a', B = 'b' }` unless there's a runtime need for the enum.

**Modern patterns to prefer:**
- `satisfies` for config objects: `const config = { ... } satisfies Config`
- `as const` for literal preservation
- `const` type parameters (TS 5.0+) where applicable
- Template literal types for string patterns
- `using` / `Symbol.dispose` (TS 5.2+) for resource cleanup
- Plain unions (`T | null`, `T | undefined`) over homegrown `Optional<T>` wrappers for simple nullable types

## Stale Patterns (Lies)

- `require()` in TypeScript/ESM projects -> `import`
- `module.exports` when the project uses ESM -> `export`
- `var` -> `const` / `let`
- `arguments` object -> rest parameters
- `Promise` constructor for async operations -> `async`/`await`
- `React.FC` type (unnecessary since React 18) -> type props directly
- Class components in React -> function components + hooks
- `PropTypes` alongside TypeScript -> redundant, remove
- `namespace` -> modules
- `/// <reference>` directives -> proper imports
- `.then()` chains -> async/await (except when composing promise combinators)
- `Object.assign({}, ...)` -> spread syntax
- `Array.prototype.forEach` for side-effect-free transforms -> `.map()`

## Verbose Patterns (Noise)

- `for` loops that should be `.filter().map()` or `.reduce()`
- `.then()` chains instead of async/await
- Manual `Promise.all()` where sequential flow is fine (or vice versa)
- Unnecessary intermediate variables: `const result = foo(); return result;`
- `class` for stateless logic that should be plain functions
- `Object.keys(x).forEach()` -> `for (const key of Object.keys(x))`
- Ternaries wrapping booleans: `return x ? true : false` -> `return x`
- Spread-then-override for single property: `{...obj, key: value}` when `obj.key = value` works on a local mutable
- `new Promise((resolve, reject) => { asyncFn().then(resolve).catch(reject) })` (the Promise constructor anti-pattern)
- `Array.from(set).map(...)` when `[...set].map(...)` works

## Dependency Creep (Lies)

- `node-fetch` when `fetch` is global (Node 18+, Bun, Deno)
- `uuid` when `crypto.randomUUID()` exists
- `lodash.get` / `lodash.set` when optional chaining and nullish coalescing exist
- `moment` / `dayjs` for simple ISO date formatting (`Intl.DateTimeFormat`, `Date.toISOString()`)
- Two HTTP clients (e.g., `axios` + `node-fetch`)
- Two date libraries
- `dotenv` when the runtime supports `.env` natively (Bun, Deno, Node 20.6+)

## AI-Native Tells (Lies + Soul)

Patterns that often look polished enough to pass review unless someone asks, "Why does this exist?"

**Detect:**
- `try/catch` around deterministic local code (`console.*`, object spreads, pure transforms) where the catch only logs or returns a fallback
- `new Promise(async (resolve, reject) => { ... })` or extra promise wrappers around already-async code
- Required env/config read with a silent default: `process.env.API_URL ?? 'http://localhost:3000'` in production code
- Internal helper calls guarded with `if (!response.ok)` or null checks even though the helper already normalizes failures
- Tests that only assert `toHaveBeenCalledTimes`, exact mock arguments, or snapshots without checking returned behavior
- Invented framework APIs, hook options, or config keys that are not present in local types or docs

**Fix:** Delete defensive wrappers that add no recovery. Fail loudly on required config. Let the type system and real boundary checks do the work. For suspected hallucinations, check the project's installed types, generated docs, or framework docs before flagging.

## Barrel Files (Noise)

- `index.ts` re-exporting everything in directories with 2-3 files
- Re-exports that make it harder to find where things are defined
- `export * from './thing'` chains that hide the actual source

**When barrels are fine:** large module boundaries with stable public APIs (e.g., a shared library's entry point).
