# Language-Specific Test Patterns

Idiomatic test patterns for JS/TS, Python, Go, and Rust. Each section covers test structure, mocking, async testing, table-driven tests, and common pitfalls.

---

## JavaScript / TypeScript (Vitest, Jest)

Vitest is the default for Vite-based projects. Jest for everything else. The APIs are nearly identical -- Vitest implements Jest's `expect` API with Vite-native module resolution and HMR.

### Test structure

```typescript
// Vitest / Jest
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
// For Jest: import from "@jest/globals" or use globals

describe("CartService", () => {
  let cart: CartService;

  beforeEach(() => {
    cart = new CartService();
  });

  it("applies 10% discount when total exceeds 100", () => {
    cart.addItem({ name: "Widget", price: 120 });
    expect(cart.total()).toBe(108);
  });

  it("throws when adding item with negative price", () => {
    expect(() => cart.addItem({ name: "Bad", price: -1 })).toThrow("Price must be positive");
  });
});
```

### Mocking

```typescript
// Vitest -- module mock
vi.mock("./api-client", () => ({
  fetchUser: vi.fn().mockResolvedValue({ id: 1, name: "Test" }),
}));

// Vitest -- spy on existing method
const spy = vi.spyOn(service, "save");
await service.process(data);
expect(spy).toHaveBeenCalledWith(expect.objectContaining({ status: "complete" }));

// Vitest -- timer mocking
vi.useFakeTimers();
setTimeout(callback, 1000);
vi.advanceTimersByTime(1000);
expect(callback).toHaveBeenCalled();
vi.useRealTimers();

// Jest equivalents: jest.mock(), jest.spyOn(), jest.useFakeTimers()
```

**Mock cleanup**: always restore mocks in `afterEach` or use `vi.restoreAllMocks()` / `jest.restoreAllMocks()`. Leaked mocks between tests cause phantom failures.

### Async testing

```typescript
// Async/await (preferred)
it("fetches user data", async () => {
  const user = await getUser(1);
  expect(user.name).toBe("Alice");
});

// Reject assertion
it("rejects with 404 for missing user", async () => {
  await expect(getUser(999)).rejects.toThrow("Not found");
});

// WRONG: missing await -- test passes even if assertion fails
it("BROKEN -- no await", () => {
  expect(getUser(999)).rejects.toThrow("Not found"); // resolves after test ends
});
```

### Snapshot testing

```typescript
it("renders user card", () => {
  const { container } = render(<UserCard user={testUser} />);
  expect(container).toMatchSnapshot();
});

// Inline snapshots (preferred -- visible in the test file)
it("formats currency", () => {
  expect(formatCurrency(1234.5)).toMatchInlineSnapshot(`"$1,234.50"`);
});
```

**Snapshot rules**: review diffs before updating. Use inline snapshots for small values. Don't snapshot entire pages -- snapshot specific components or data structures.

### Testing Library (React, Vue, Svelte)

```typescript
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

it("submits the form with user input", async () => {
  const onSubmit = vi.fn();
  render(<LoginForm onSubmit={onSubmit} />);

  await userEvent.type(screen.getByRole("textbox", { name: /email/i }), "test@example.com");
  await userEvent.type(screen.getByLabelText(/password/i), "secret123");
  await userEvent.click(screen.getByRole("button", { name: /sign in/i }));

  expect(onSubmit).toHaveBeenCalledWith({
    email: "test@example.com",
    password: "secret123",
  });
});
```

**Query priority** (from Testing Library docs):
1. `getByRole` -- accessible, resilient to DOM changes
2. `getByLabelText` -- form elements
3. `getByPlaceholderText` -- fallback for unlabeled inputs
4. `getByText` -- non-interactive elements
5. `getByTestId` -- last resort

Never query by CSS class, tag name, or DOM hierarchy. Those break on every design change.

### Table-driven tests (Vitest/Jest)

```typescript
it.each([
  { input: "",        expected: false, desc: "empty string" },
  { input: "abc",     expected: false, desc: "no digits" },
  { input: "abc123",  expected: true,  desc: "mixed" },
  { input: "123",     expected: true,  desc: "all digits" },
])("hasDigits($input) returns $expected ($desc)", ({ input, expected }) => {
  expect(hasDigits(input)).toBe(expected);
});
```

### Common Vitest/Jest pitfalls

- **Forgetting `await`** on async assertions (`expect(...).rejects`). Test passes silently.
- **Mutating shared test data** between tests. Use `beforeEach` to reset.
- **Over-mocking**: mocking the module under test. You're testing your mock, not your code.
- **`toBe` vs `toEqual`**: `toBe` uses `Object.is` (reference equality). Use `toEqual` for deep equality on objects/arrays.
- **Timer leaks**: `vi.useFakeTimers()` without `vi.useRealTimers()` in `afterEach` breaks subsequent tests.
- **Module mock hoisting**: `vi.mock()` / `jest.mock()` calls are hoisted to the top of the file. Variables defined before the mock aren't available inside the mock factory.

---

## Python (pytest)

pytest is the standard. Don't use `unittest.TestCase` subclasses unless maintaining a legacy test suite.

### Test structure

```python
# test_cart.py
import pytest
from cart import CartService

@pytest.fixture
def cart():
    return CartService()

def test_applies_discount_when_total_exceeds_100(cart):
    cart.add_item(name="Widget", price=120)
    assert cart.total() == 108

def test_raises_on_negative_price(cart):
    with pytest.raises(ValueError, match="Price must be positive"):
        cart.add_item(name="Bad", price=-1)
```

### Fixtures

```python
# conftest.py -- shared fixtures
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

@pytest.fixture(scope="session")
def engine():
    """One engine per test session."""
    eng = create_engine("postgresql://test:test@localhost:5432/testdb")
    yield eng
    eng.dispose()

@pytest.fixture
def db(engine):
    """Transaction-scoped DB session -- rolls back after each test."""
    connection = engine.connect()
    transaction = connection.begin()
    session = Session(connection)  # SQLAlchemy 2.x: pass connection positionally
    yield session
    session.close()
    transaction.rollback()
    connection.close()

@pytest.fixture
def tmp_config(tmp_path):
    """Config file in a temp directory."""
    config = tmp_path / "config.yaml"
    config.write_text("key: value\n")
    return config
```

**Fixture scopes**: `function` (default, per-test), `class`, `module`, `session`. Use the narrowest scope that doesn't kill performance. Session-scoped fixtures with mutable state are shared-state bugs waiting to happen.

### Mocking

```python
# monkeypatch (preferred for simple cases)
def test_reads_from_env(monkeypatch):
    monkeypatch.setenv("API_KEY", "test-key-123")
    assert get_api_key() == "test-key-123"

# unittest.mock for complex cases
from unittest.mock import patch, AsyncMock

@patch("myapp.api.client.fetch", new_callable=AsyncMock)
async def test_service_calls_api(mock_fetch):
    mock_fetch.return_value = {"status": "ok"}
    result = await my_service.process()
    assert result.status == "ok"
    mock_fetch.assert_called_once()
```

**Prefer `monkeypatch` over `@patch`** for simple attribute/env overrides. `monkeypatch` auto-reverts in teardown and reads more clearly. Use `unittest.mock` when you need `call_args`, `side_effect`, or complex mock behavior.

### Parametrize (table-driven tests)

```python
@pytest.mark.parametrize("input_val,expected", [
    ("", False),
    ("abc", False),
    ("abc123", True),
    ("123", True),
], ids=["empty", "no-digits", "mixed", "all-digits"])
def test_has_digits(input_val, expected):
    assert has_digits(input_val) == expected
```

### Async testing

```python
# pytest-asyncio
import pytest

@pytest.mark.asyncio
async def test_async_fetch():
    result = await fetch_data("https://api.example.com/data")
    assert result["status"] == "ok"
```

Requires `pytest-asyncio` and `asyncio_mode = "auto"` in `pyproject.toml` (or `"strict"` with explicit markers).

### Common pytest pitfalls

- **Mutable default fixture data**: returning a dict from a session-scoped fixture that tests modify. Each test sees mutations from previous tests.
- **Missing `@pytest.mark.asyncio`**: async test runs but never actually awaits anything. Passes silently.
- **`assert obj`** instead of `assert obj is not None`: truthy check catches more than intended (empty list is falsy).
- **Fixture dependency order**: fixtures execute top-to-bottom in the parameter list. If fixture B depends on fixture A, list A first.
- **`tmp_path` vs `tmp_path_factory`**: `tmp_path` is per-test (function scope). Use `tmp_path_factory` for wider scopes.

---

## Go (testing stdlib)

Go's testing package is minimal by design. No assertions library built in (use `testify` if you want `assert`/`require`, or write plain `if` checks). Test files end in `_test.go` and live alongside the code.

### Test structure

```go
// cart_test.go
package cart

import "testing"

func TestAppliesDiscountWhenTotalExceeds100(t *testing.T) {
    c := NewCart()
    c.AddItem(Item{Name: "Widget", Price: 120})

    got := c.Total()
    want := 108.0

    if got != want {
        t.Errorf("Total() = %v, want %v", got, want)
    }
}

func TestRaisesOnNegativePrice(t *testing.T) {
    c := NewCart()
    err := c.AddItem(Item{Name: "Bad", Price: -1})
    if err == nil {
        t.Fatal("expected error for negative price, got nil")
    }
}
```

### Table-driven tests (the Go pattern)

```go
func TestHasDigits(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  bool
    }{
        {"empty string", "", false},
        {"no digits", "abc", false},
        {"mixed", "abc123", true},
        {"all digits", "123", true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := HasDigits(tt.input)
            if got != tt.want {
                t.Errorf("HasDigits(%q) = %v, want %v", tt.input, got, tt.want)
            }
        })
    }
}
```

### Mocking via interfaces

Go has no mocking framework in the stdlib. The idiomatic pattern is to define interfaces at the consumer, then inject fakes in tests:

```go
// production code
type UserStore interface {
    GetUser(ctx context.Context, id string) (*User, error)
}

type Service struct {
    store UserStore
}

// test code
type fakeStore struct {
    users map[string]*User
}

func (f *fakeStore) GetUser(_ context.Context, id string) (*User, error) {
    u, ok := f.users[id]
    if !ok {
        return nil, ErrNotFound
    }
    return u, nil
}

func TestServiceGetUser(t *testing.T) {
    store := &fakeStore{users: map[string]*User{"1": {ID: "1", Name: "Alice"}}}
    svc := &Service{store: store}
    // ...
}
```

For generated mocks, use `go.uber.org/mock` (formerly `golang/mock`). Avoid `testify/mock` -- the untyped API (`On("Method", args).Return(...)`) catches zero compile-time errors.

### Test cleanup and temp dirs

```go
func TestWithTempDir(t *testing.T) {
    dir := t.TempDir() // auto-cleaned after test
    // write files to dir...
}

func TestWithCleanup(t *testing.T) {
    db := setupTestDB(t)
    t.Cleanup(func() { db.Close() })
    // ...
}
```

### HTTP handler testing

```go
func TestHealthHandler(t *testing.T) {
    req := httptest.NewRequest("GET", "/health", nil)
    rec := httptest.NewRecorder()

    HealthHandler(rec, req)

    if rec.Code != http.StatusOK {
        t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
    }
}
```

### Benchmarks

```go
func BenchmarkHash(b *testing.B) {
    data := []byte("benchmark input")
    for b.Loop() {  // Go 1.24+: b.Loop() replaces manual b.N loop
        Hash(data)
    }
}
// Run: go test -bench=BenchmarkHash -benchmem
```

### Common Go testing pitfalls

- **`t.Errorf` vs `t.Fatalf`**: `Errorf` continues execution. Use `Fatalf` when further assertions depend on this one passing.
- **Parallel test data races**: `t.Parallel()` without protecting shared state. Run with `-race` flag.
- **Test binary caching**: `go test` caches results. Use `-count=1` to force re-run.
- **Missing `t.Helper()`**: helper functions that call `t.Errorf` report the wrong line. Mark them with `t.Helper()`.
- **`testing/synctest`**: Go 1.25 promoted `synctest` from experiment to stdlib. Go 1.26 replaced `synctest.Run` with `synctest.Test` (accepts `*testing.T`). Use `synctest.Test(t, func(t *testing.T) { ... })` to test concurrent code in an isolated "bubble" -- fake clock, deterministic goroutine scheduling, no real sleeps needed.

---

## Rust (cargo test, cargo-nextest)

Rust's test framework is built into the language. Unit tests go in the same file as the code (in a `#[cfg(test)]` module). Integration tests go in `tests/`.

### Test structure

```rust
// src/cart.rs
pub fn total_with_discount(items: &[Item]) -> f64 {
    let total: f64 = items.iter().map(|i| i.price).sum();
    if total > 100.0 { total * 0.9 } else { total }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn applies_discount_when_total_exceeds_100() {
        let items = vec![Item { name: "Widget".into(), price: 120.0 }];
        let result = total_with_discount(&items);
        assert!((result - 108.0).abs() < f64::EPSILON);
    }

    #[test]
    #[should_panic(expected = "Price must be positive")]
    fn panics_on_negative_price() {
        let items = vec![Item { name: "Bad".into(), price: -1.0 }];
        total_with_discount(&items);
    }
}
```

### Integration tests

```rust
// tests/api_test.rs (separate binary, tests public API only)
use mylib::CartService;

#[test]
fn cart_integration_test() {
    let mut cart = CartService::new();
    cart.add_item("Widget", 120.0).unwrap();
    assert_eq!(cart.total(), 108.0);
}
```

### Async testing (tokio)

```rust
#[tokio::test]
async fn fetches_user_data() {
    let client = TestClient::new();
    let user = client.get_user(1).await.unwrap();
    assert_eq!(user.name, "Alice");
}
```

### Test utilities

```rust
// Temp directory (auto-cleaned)
use tempfile::TempDir;

#[test]
fn writes_config_to_disk() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().join("config.toml");
    write_config(&path).unwrap();
    assert!(path.exists());
}
// TempDir dropped here, directory cleaned up
```

### cargo-nextest

`cargo nextest run` is a drop-in replacement that runs each test in its own process. Benefits: true parallel execution (up to 60% faster), flaky test retry with `--retries` (marks flaky when a retry passes), per-test timeout enforcement, and better CI output (JUnit XML).

```bash
# Install
cargo install cargo-nextest

# Run all tests
cargo nextest run

# With retries for flaky tests
cargo nextest run --retries 2

# Generate JUnit report for CI
cargo nextest run --profile ci
```

### Common Rust testing pitfalls

- **Float comparison**: `assert_eq!` on floats fails on rounding. Use `assert!((a - b).abs() < EPSILON)` or the `approx` crate.
- **`#[should_panic]` without `expected`**: catches ANY panic, including unrelated ones. Always provide the expected message substring.
- **Integration test compilation**: each file in `tests/` compiles as a separate crate. For shared test utilities, use `tests/common/mod.rs` (not `tests/common.rs`, which Rust treats as a test file).
- **`Drop` for cleanup**: use Rust's ownership model -- temp resources wrapped in structs with `Drop` impls get cleaned up automatically, even on test failure.
- **Mocking**: Rust has no built-in mock framework. Use trait objects with fake implementations (like Go), or the `mockall` crate for generated mocks. `mockall` uses proc macros and can slow compilation.
