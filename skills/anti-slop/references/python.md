# Python Slop Patterns

## Class-for-Everything Disease (Soul)

The Java brain transplant. Python modules are already namespaces -- you don't need a class to group functions.

**Detect:**
- Classes with no `__init__` state (all `@staticmethod` or `@classmethod`)
- Classes instantiated once and never stored
- `class Config:` wrapping class-level attributes (just use a dict, dataclass, or module-level constants)
- Inheritance hierarchies for things that could be plain functions with a dict dispatch
- `class Singleton:` -- Python has modules, which are already singletons

**Fix:** Use plain functions at module level. Use `dataclass` or `NamedTuple` for data containers. Use dicts or match/case for dispatch.

## Stale Patterns (Lies)

- `os.path.join()` -> `pathlib.Path()` operations
- `"{}".format(x)` or `"%s" % x` -> f-strings
- `typing.Optional[X]` -> `X | None` (3.10+)
- `typing.Union[X, Y]` -> `X | Y` (3.10+)
- `typing.List[X]` -> `list[X]` (3.9+)
- `typing.Dict[K, V]` -> `dict[K, V]` (3.9+)
- `if/elif/elif/else` chains on a single value -> `match`/`case` (3.10+)
- `open()` without context manager -> `with open() as f:`
- Manual `__enter__`/`__exit__` -> `@contextmanager` decorator
- `try/finally` for cleanup -> context managers or `atexit`
- `dict()` constructor -> `{}` literal
- `list()` constructor -> `[]` literal

## Type Hint Abuse (Noise)

- `Any` used to bypass type errors instead of fixing the actual type
- Redundant hints on obvious assignments: `x: int = 5`
- Overly complex `TypeVar` gymnastics when a simple union works
- `# type: ignore` scattered everywhere instead of fixing the types
- `cast()` to force types instead of fixing data flow
- Type stubs for code you control (just add the hints inline)

## Verbose Patterns (Noise)

```python
# slop: manual dict building
result = {}
for item in items:
    result[item.key] = item.value

# better
result = {item.key: item.value for item in items}
```

```python
# slop: nested if instead of early return
def process(x):
    if x is not None:
        if x.valid:
            return do_thing(x)
    return None

# better
def process(x):
    if x is None or not x.valid:
        return None
    return do_thing(x)
```

- `lambda` assigned to a variable -> just use `def`
- `map(lambda x: ..., items)` -> list comprehension
- `filter(lambda x: ..., items)` -> list comprehension with `if`
- Manual `enumerate` index tracking -> `for i, item in enumerate(items)`
- `len(x) == 0` -> `not x`
- `if x == True` -> `if x`
- `if x == None` -> `if x is None`
- Importing and immediately aliasing: `import numpy as np` is fine, but `from foo import bar as bar` is not

## Dependency Creep (Lies)

- `requests` for a single GET when `urllib.request.urlopen()` works
- `python-dotenv` when `os.environ.get()` is fine
- `click` for a 3-flag CLI when `argparse` works
- `pydantic` for a single validation when a dataclass with `__post_init__` works
- `PyYAML` + `toml` + `configparser` -- pick one config format

## God-Module Refactoring (Soul)

A `utils.py` or `helpers.py` that grows past ~200 lines is a junk drawer. Split by domain:

```
# before: utils.py with 40 unrelated functions
utils.py

# after: split by concern
strings.py      # slugify, truncate, strip_tags
dates.py        # parse_date, format_iso, business_days
files.py        # safe_write, atomic_replace, ensure_dir
http.py         # retry_get, parse_json_response
```

Each module should have a single clear domain. If a function doesn't fit any domain file, it probably belongs closer to its only caller -- inline it. Don't create a `misc.py` to hold the leftovers.

**Rule of thumb:** if two functions in the same utils file never import each other and serve different callers, they belong in different modules.

## Cross-Language Tells in Python (Lies)

AI-generated Python frequently leaks JavaScript or Java idioms:

```python
# JS brain: .forEach(), .push(), .length, ===, console.log()
items.forEach(lambda x: process(x))   # not valid Python
results.push(item)                     # list.append(item)
if len(items) === 0:                   # == not ===; also: `not items`

# Java brain: .equals(), .toString(), StringBuilder
if name.equals(other)                  # name == other
str_val = obj.toString()               # str(obj)
```

These never appear in human-written Python. If you see them, the code was generated without language-aware review.

## Error Handling (Noise + Lies)

```python
# slop: bare except
try:
    do_thing()
except:
    pass

# slop: catch-log-continue
try:
    do_thing()
except Exception as e:
    print(f"Error: {e}")

# better: catch specific, handle or propagate
try:
    do_thing()
except ConnectionError:
    return fallback_value()
```

- `except Exception:` catching everything instead of specific exceptions
- `except: pass` -- silent swallow with no comment
- `logging.exception()` in every function instead of at boundaries
- Re-raising as generic `RuntimeError` losing the original exception type
