# Rust Slop Patterns

Light reference. Rust's compiler catches a lot of slop at compile time, but AI-generated Rust has its own tells.

## Clone Abuse (Soul)

The biggest AI-Rust tell. Models reach for `.clone()` to make the borrow checker shut up.

**Detect:**
- `.clone()` on values that could be borrowed (`&` or `&str` instead of `String`)
- `.clone()` inside loops (allocating on every iteration)
- `to_string()` / `to_owned()` when a `&str` would work
- Cloning large structs instead of wrapping in `Arc` or passing by reference

**Fix:** Borrow instead of cloning. If shared ownership is needed, use `Rc`/`Arc`. If mutation is needed, use `RefCell`/`Mutex`.

```rust
// SLOP: cloning to dodge the borrow checker
fn process(data: Vec<String>) {
    let copy = data.clone();
    do_thing(&data);
    do_other_thing(&copy);
}

// CLEAN: just borrow
fn process(data: &[String]) {
    do_thing(data);
    do_other_thing(data);
}
```

## Error Type Proliferation (Soul)

AI loves creating a custom error enum for every module.

**Detect:**
- Custom error enums with 1-2 variants (just use the underlying error or `anyhow`)
- `impl From<X> for MyError` boilerplate for every error type (use `thiserror` derive)
- `.unwrap()` everywhere in non-prototype code
- `.expect("should never happen")` on fallible operations that absolutely can happen
- `Box<dyn Error>` as return type when `anyhow::Result` is in the deps

**Fix:** For applications, use `anyhow`. For libraries, use `thiserror`. Don't hand-roll error types unless you need stable public API error variants.

## Overly Generic Trait Bounds (Noise)

**Detect:**
- Functions generic over `T: Display + Debug + Clone + Send + Sync` when they only use `Display`
- Trait bounds that exist "for future flexibility" but only one type is ever passed
- `impl<T: AsRef<str>>` when the function is only called with `&str`

**Fix:** Use the minimum bounds needed. Concrete types are fine when there's only one caller.

## Verbose Patterns (Noise)

**Detect:**
- `match` with two arms where `if let` would do
- `match x { true => ..., false => ... }` instead of `if x { ... } else { ... }`
- Manual `Option`/`Result` matching instead of combinators (`.map()`, `.and_then()`, `.unwrap_or()`)
- `return` keyword at the end of a function (Rust returns the last expression)
- `let x = x;` rebinding without type change or mutability change

**Fix:**
```rust
// SLOP
match maybe_value {
    Some(v) => do_thing(v),
    None => {},
}

// CLEAN
if let Some(v) = maybe_value {
    do_thing(v);
}
```

## Unsafe Overuse (Lies)

**Detect:**
- `unsafe` blocks for operations that have safe alternatives
- `unsafe` without a `// SAFETY:` comment explaining the invariant
- `transmute` when `as` casting or `From`/`Into` would work
- Raw pointer manipulation that could use `slice::from_raw_parts` or similar safe wrappers

**Fix:** Remove unsafe when a safe API exists. When unsafe is genuinely needed, document the safety invariant.

## Stale Patterns (Lies)

**Detect:**
- `extern crate` (unnecessary since Rust 2018 edition)
- `#[macro_use]` for importing macros (use `use` instead, 2018+)
- Old-style `try!()` macro instead of `?` operator
- Manual `impl Iterator` when `impl IntoIterator` or iterator combinators work
- `String::from("...")` when `"...".to_string()` or `.into()` reads cleaner (style preference, not wrong)

## Dependency Creep (Noise)

**Detect:**
- `regex` crate for simple string matching (`contains()`, `starts_with()`, `split()`)
- `chrono` when `time` crate or `std::time` suffices
- `lazy_static` when `std::sync::LazyLock` exists (Rust 1.80+, `get`/`get_mut`/`force_mut` stabilized in 1.94)
- `rand` for a single random number when `getrandom` or `fastrand` is lighter
- Multiple serialization crates when only `serde` is needed

## Supply Chain Risk (Lies)

**High-risk crates** (active CVEs, March 2026):
- `tar`, `async-tar`, `tokio-tar` -- CVE-2026-33056 (symlink-following RCE during `cargo build`). Pin `tar >= 0.4.45`. Fix shipped in Rust 1.94.0 (released March 5, 2026). Affects uv, testcontainers, wasmCloud.
- Rust supply chain attacks up 130% in 2025. Crates.io deploying TUF (The Update Framework) in 2026.

**Detect:**
- Unpinned `tar`/`async-tar`/`tokio-tar` in `Cargo.toml`
- `cargo audit` not in CI pipeline
- No `Cargo.lock` committed (for binaries/applications -- libraries should omit it)

**Deeper tools** (beyond `cargo audit`):
- `cargo-geiger` -- maps unsafe usage across entire dependency graph
- `cargo-deny` -- gates duplicate crates, disallowed sources, license policy
- `Miri` -- runtime interpreter catching undefined behavior in unsafe code
- `Rudra` -- detects Rust-specific anti-patterns (unsafe + unwinding + trait system interactions)

Layer **EPSS** and **CISA KEV** scoring on cargo-audit findings to prioritize actually-exploited vulns over theoretical ones.
