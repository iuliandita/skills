# Python Bug Patterns

Bug patterns specific to Python. Focused on correctness - not style (see anti-slop) or security (see security-audit).

---

## Mutable Default Arguments

The single most common Python bug. Default mutable arguments are shared across all calls.

**Detect:**
- `def foo(items=[])`, `def foo(config={})`, `def foo(seen=set())`
- Any mutable type (list, dict, set, bytearray) as a default parameter value

**Example:**
```python
# bug: items list is shared across all calls
def append_to(item, items=[]):
    items.append(item)
    return items

append_to(1)  # [1]
append_to(2)  # [1, 2] - not [2]!

# fix: use None sentinel
def append_to(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items
```

---

## Exception Handling Bugs

### Bare `except:`

Catches everything including KeyboardInterrupt, SystemExit, and GeneratorExit.

**Detect:**
- `except:` without specifying exception type
- `except Exception:` when `except (SpecificError1, SpecificError2):` would be correct
- `except BaseException:` (same problem as bare except)

### Exception Chain Loss

Re-raising exceptions without preserving the original cause.

**Detect:**
- `raise NewError("msg")` inside an except block (loses original traceback)
- Missing `from` clause: `raise NewError("msg") from original_err`
- `raise` vs `raise err` (the former preserves traceback, the latter may not in Python 2-style patterns)

**Example:**
```python
# bug: original traceback is lost
try:
    parse_config(path)
except ValueError:
    raise RuntimeError("bad config")  # no idea what the original error was

# fix: chain the exception
try:
    parse_config(path)
except ValueError as e:
    raise RuntimeError(f"bad config: {path}") from e
```

### Swallowed Exceptions in Context Managers

`__exit__` returning True suppresses the exception silently.

**Detect:**
- Custom context managers where `__exit__` returns True unconditionally
- `contextlib.suppress()` used too broadly (suppressing more than intended)

---

## Iterator & Generator Bugs

### Generator Exhaustion

Generators can only be iterated once. Second iteration silently yields nothing.

**Detect:**
- Generator assigned to a variable and iterated multiple times
- `map()`, `filter()`, `zip()` results used more than once (they return iterators in Python 3)
- Generator passed to a function that iterates it, then iterated again by the caller

**Example:**
```python
# bug: second loop iterates nothing
filtered = (x for x in data if x > 0)
total = sum(filtered)
items = list(filtered)  # always empty!

# fix: use a list if you need to iterate multiple times
filtered = [x for x in data if x > 0]
```

### `StopIteration` Leaking

`StopIteration` raised inside a generator silently stops it (PEP 479 changed this in 3.7, but older code or `__next__` calls can still be affected).

**Detect:**
- Calling `next()` without a default inside a generator function
- Manual `__next__()` calls without try/except

---

## Scope & Binding Bugs

### Late Binding Closures

Python closures bind by name, not by value. Loop variables in closures all reference the final value.

**Detect:**
- Lambda or function defined in a loop and used later
- List comprehensions creating closures over loop variables
- Callbacks registered in a loop

**Example:**
```python
# bug: all functions return 4
funcs = [lambda: i for i in range(5)]
[f() for f in funcs]  # [4, 4, 4, 4, 4]

# fix: bind with default argument
funcs = [lambda i=i: i for i in range(5)]
[f() for f in funcs]  # [0, 1, 2, 3, 4]
```

### `global` / `nonlocal` Surprises

- Reading a variable works (closure), but assigning creates a new local - `UnboundLocalError` if you read before write without `global`/`nonlocal`
- `nonlocal` required to mutate enclosing scope variables (not just read)

---

## Import & Module Bugs

### Circular Imports

Two modules importing each other, causing `ImportError` or partially-initialized modules.

**Detect:**
- Module A imports from Module B, and Module B imports from Module A
- `ImportError: cannot import name 'X'` at runtime
- Imports inside function bodies (often a workaround for circular imports - the real fix is restructuring)

### Module-Level Side Effects

Code that runs on import, not on use.

**Detect:**
- Database connections opened at module level
- Network requests during import
- File I/O in module body
- Heavy computation at import time
- Global mutable state initialized at import

---

## Async / Await Bugs

### Blocking the Event Loop

Sync operations in async code blocks the entire event loop.

**Detect:**
- `time.sleep()` in async functions (use `asyncio.sleep()`)
- Sync file I/O (`open()`, `pathlib.Path.read_text()`) in async context
- Sync HTTP requests (`requests.get()`) in async code
- CPU-heavy computation without `loop.run_in_executor()`

### Missing `await`

Same pattern as JavaScript - forgetting `await` on a coroutine.

**Detect:**
- Coroutine called without `await` (Python warns: "coroutine was never awaited")
- `await` inside a non-async function (SyntaxError, but can be confusing in nested contexts)
- Async generators vs async functions confusion

### Async Context Manager Misuse

- Using `with` instead of `async with` on async context managers
- `async for` vs `for` on async iterators

---

## Data Structure Bugs

### Dictionary Mutation During Iteration

Modifying a dict while iterating raises `RuntimeError` in Python 3.

**Detect:**
- `for key in dict:` followed by `del dict[key]` or `dict[new_key] = ...`
- Same pattern with sets
- Workaround check: iterating over `list(dict.keys())` is fine

### Shallow vs Deep Copy

`copy()` and `[:]` make shallow copies. Nested mutable objects are still shared.

**Detect:**
- `list.copy()` or `dict.copy()` on nested structures and then modifying inner elements
- Default `copy.copy()` when `copy.deepcopy()` is needed
- Slice assignment `new = old[:]` on lists containing mutable objects

### `is` vs `==`

- `is` compares identity (same object), `==` compares value
- Works "accidentally" for small ints (-5 to 256) due to interning
- `is None` is correct; `is True` / `is False` is fragile; `is "string"` is wrong

---

## Type Hint Bugs

These are bugs where type hints lie about what the code actually does.

**Detect:**
- Function annotated `-> str` but can return `None` (should be `-> str | None`)
- `list[str]` annotation on a variable that actually contains mixed types
- `TypedDict` with required keys that the code doesn't always provide
- `cast()` used to silence mypy when the actual type is wrong (same problem as TS `as`)
- `# type: ignore` comments hiding real type errors

---

## Dataclass & Pydantic Bugs

### Mutable Default Fields

Same concept as mutable default arguments, but sneakier because the syntax looks safe.

**Detect:**
- `@dataclass` with `field: list = []` or `field: dict = {}` (shared across instances)
- Missing `field(default_factory=list)` or `field(default_factory=dict)`
- Pydantic models with mutable defaults in `Field()` (pydantic v2 handles this better, but v1 doesn't)

**Example:**
```python
# bug: all instances share the same list
@dataclass
class Config:
    tags: list[str] = []  # shared mutable default!

a = Config()
b = Config()
a.tags.append("x")
print(b.tags)  # ['x'] - oops

# fix: use default_factory
@dataclass
class Config:
    tags: list[str] = field(default_factory=list)
```

### Pydantic Validator Side Effects

**Detect:**
- `@field_validator` / `@model_validator` that mutates external state (database calls, file writes)
- Validators that assume execution order (field validators run in definition order, but this is fragile)
- `model_validate()` on untrusted input without `strict=True` (pydantic coerces by default: `"123"` becomes `123`)

### `__post_init__` Gotchas

**Detect:**
- `__post_init__` in frozen dataclasses (can't set fields, must use `object.__setattr__`)
- Heavy computation in `__post_init__` (runs on every instantiation, including deserialization)
- `__post_init__` calling methods that rely on fields set by subclasses (not initialized yet)

---

## Attribute Typo Bugs

Python happily creates new attributes on regular classes when you typo a name.

**Detect:**
- `self.nmae = name` (typo creates a new attribute, no error)
- Attribute access in `__init__` that doesn't match any defined attribute
- Classes without `__slots__` where attribute typos would be silently accepted

**Example:**
```python
# bug: typo creates a new attribute, self.name stays None
class User:
    def __init__(self, name: str):
        self.name = None
        self.nmae = name  # typo, no error!

# fix: use __slots__ to catch typos at runtime
class User:
    __slots__ = ('name',)
    def __init__(self, name: str):
        self.nmae = name  # AttributeError!
```

**Fix:** Use `__slots__` on classes where attribute safety matters. Or use `@dataclass` which defines attributes explicitly.

---

## Numeric & String Bugs

### Integer Division

- `//` (floor division) vs `/` (true division) confusion
- Negative number floor division: `-7 // 2 == -4` (not -3)
- `round()` uses banker's rounding: `round(0.5) == 0`, `round(1.5) == 2`

### String Encoding

- `str` vs `bytes` confusion when doing I/O
- `.encode()` / `.decode()` with wrong encoding (UTF-8 assumed, but data is Latin-1)
- `len()` returning code points, not grapheme clusters (emoji, combining characters)
