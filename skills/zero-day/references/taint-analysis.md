# Manual Taint Analysis Methodology

Step-by-step methodology for tracing untrusted data from entry points (sources) to
security-sensitive operations (sinks). This is the core technique for finding injection,
SSRF, path traversal, and other data-flow vulnerabilities in source code.

---

## Core Concept

Taint analysis answers one question: **can an attacker control data that reaches a
dangerous operation?**

```
[SOURCE] ---> [transforms/sanitizers] ---> [SINK]
  ^                                          ^
  untrusted data enters                      security impact occurs
```

A vulnerability exists when a path from source to sink has inadequate or bypassable
sanitization.

---

## Step 1: Map Sources (Where Untrusted Data Enters)

### Web Applications

| Source type | Examples |
|-------------|----------|
| HTTP params | query string, POST body, form data, multipart uploads |
| HTTP headers | `Host`, `Referer`, `X-Forwarded-For`, `Cookie`, custom headers |
| URL path | route parameters, path segments |
| WebSocket | message frames |
| File uploads | filename, content, MIME type |

### APIs and Services

| Source type | Examples |
|-------------|----------|
| Request body | JSON, XML, protobuf, GraphQL queries |
| gRPC | message fields, metadata |
| Message queues | Kafka/RabbitMQ message payloads, headers |
| Database results | data originally from user input (second-order) |

### System/Binary

| Source type | Examples |
|-------------|----------|
| stdin/argv | command-line arguments, piped input |
| Files | config files, data files, log files (if attacker can influence) |
| Environment | env vars, especially in container/cloud contexts |
| Network | raw sockets, DNS responses, IPC messages |
| Shared memory | mmap regions written by other processes |

### Second-Order Sources

Data that was safely stored but becomes untrusted when read back:
- Database fields containing user input from a previous request
- Log files parsed by monitoring tools
- Configuration files editable through admin UI
- Cache entries populated from user requests

---

## Step 2: Map Sinks (Where Impact Occurs)

### Critical Sinks (immediate impact)

| Sink type | Language patterns |
|-----------|-----------------|
| OS command | `system()`, `popen()`, `spawn()`, `Process`, backticks |
| SQL query | raw SQL, `.raw()`, `.execute()`, string interpolation in queries |
| File system | `open()`, `read()`, `write()`, `unlink()`, path construction |
| Code eval | `eval()`, `Function()`, template rendering |
| Deserialization | `pickle.loads()`, `ObjectInputStream`, `unserialize()`, `YAML.load()` |
| HTTP request (SSRF) | `fetch()`, `requests.get()`, `http.Get()`, `curl_exec()` |
| HTML output (XSS) | `innerHTML`, `document.write()`, `dangerouslySetInnerHTML`, `|safe` |
| LDAP query | LDAP filter construction with user input |

### Secondary Sinks (impact depends on context)

| Sink type | When dangerous |
|-----------|---------------|
| Log output | When log viewer renders HTML, or log injection affects monitoring |
| Email headers | When user data in To/Subject/headers enables header injection |
| XML construction | When user data can inject entities (XXE) or break structure |
| Redirect URL | When user controls redirect target (open redirect -> phishing, OAuth token theft) |
| Crypto operations | When user controls key, IV, plaintext that influences key derivation |

---

## Step 3: Trace Paths

For each source-sink pair that could be connected, trace the data flow.

### Manual Tracing Technique

1. **Start at the sink** (backward tracing is usually more efficient):
   - Find the dangerous function call
   - Identify which parameter contains the potentially tainted data
   - Trace that variable backward through assignments, function returns, and parameters

2. **Follow the data through transformations:**
   - String concatenation/interpolation
   - Type conversions (string to int and back, encoding changes)
   - Data structure operations (object property access, array indexing)
   - Function calls (follow into each function, note the call chain)

3. **Identify sanitization points:**
   - Input validation (regex, allowlist, type check)
   - Encoding/escaping (HTML escape, URL encode, SQL parameterization)
   - Library-provided sanitization (DOMPurify, bleach, parameterized queries)

4. **Evaluate sanitization effectiveness:**
   - Is the sanitization applied to ALL paths? (check error paths, fallback paths)
   - Is the sanitization correct for the sink type? (HTML escaping doesn't help SQL injection)
   - Can the sanitization be bypassed? (encoding tricks, type juggling, truncation)
   - Is the sanitization applied at the right point? (too early = can be undone; too late = already used)

### Assisted Tracing with Tools

**CodeQL** (best for cross-function, cross-file taint tracking):
```ql
/**
 * @name Tainted data reaching dangerous sink
 * @kind path-problem
 */
import javascript
import DataFlow::PathGraph

class TaintConfig extends TaintTracking::Configuration {
  TaintConfig() { this = "CustomTaint" }

  override predicate isSource(DataFlow::Node node) {
    // HTTP request parameters
    node instanceof RemoteFlowSource
  }

  override predicate isSink(DataFlow::Node node) {
    // Command execution
    exists(SystemCommandExecution cmd |
      node = cmd.getAnArgument()
    )
  }
}

from TaintConfig cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "Command injection from $@", source.getNode(), "user input"
```

**Semgrep** (pattern-based, good for single-file taint):
```yaml
rules:
  - id: command-injection-via-user-input
    patterns:
      - pattern-either:
          - pattern: subprocess.run($CMD, shell=True, ...)
          - pattern: os.system($CMD)
          - pattern: os.popen($CMD)
      - pattern-inside: |
          def $FUNC(..., $PARAM, ...):
              ...
      - metavariable-pattern:
          metavariable: $CMD
          pattern: |
            ... + $PARAM + ...
    message: "Possible command injection via function parameter"
    severity: ERROR
    languages: [python]
```

**Joern** (code property graph, good for C/C++):
```scala
// Find data flow from recv() to memcpy size parameter
def source = cpg.call.name("recv").argument(2)
def sink = cpg.call.name("memcpy").argument(3)
sink.reachableBy(source).flows.p
```

---

## Step 4: Evaluate Sanitization

### Common Sanitization Bypasses

**Denylist bypasses** (filtering specific patterns):
- Case variation: `SeLeCt` bypasses `select` filter
- Encoding: `%27` for `'`, `%3b` for `;`, double-encoding `%2527`
- Unicode normalization: different Unicode representations of same character
- Null bytes: `%00` truncating strings in some languages/functions
- Alternative syntax: `UNION ALL SELECT` instead of `UNION SELECT`
- Comment insertion: `SEL/**/ECT` in SQL

**Context mismatch** (wrong sanitization for the sink):
- HTML-escaping data used in JavaScript context (still XSS-able)
- URL-encoding data used in HTML attribute without quotes
- SQL-escaping data used in `ORDER BY` (can't parameterize identifiers)
- Shell-escaping that doesn't handle newlines

**Incomplete coverage:**
- Error handlers that skip sanitization
- Default/fallback paths that use raw input
- Admin endpoints that bypass input validation
- File upload handlers that check extension but not content
- API versioning where v1 has sanitization but v2 doesn't

**Truncation attacks:**
- Input truncated to N characters after sanitization adds escaping
  (escape chars push real content past buffer, gets cut off mid-escape)
- Database column length truncation creating collisions

### What Constitutes Effective Sanitization

| Sink type | Effective sanitization |
|-----------|----------------------|
| SQL | Parameterized queries (NOT escaping) |
| OS command | Argument arrays without shell (NOT escaping) |
| HTML | Context-aware escaping (HTML entity, JS string, URL, CSS) |
| File path | Resolved path starts with allowed prefix (`realpath` check) |
| URL (SSRF) | Allowlist of hosts + resolved IP check (not just hostname) |
| Deserialization | Don't deserialize untrusted data. Use safe formats (JSON, not pickle/Java serial) |

---

## Step 5: Second-Order Flows

Second-order vulnerabilities are the most commonly missed. The data enters safely, is stored,
and becomes dangerous when used later.

### Pattern

```
Request 1: user submits data -> stored safely in database
                                        |
Request 2: different code reads data -> uses it unsafely
```

### How to find

1. Identify database write operations that store user input
2. Find everywhere that data is read back
3. Check if the read-back location applies the same (or any) sanitization
4. Common locations:
   - Admin dashboards displaying user-submitted data (stored XSS)
   - Report generators using database values in SQL/commands
   - Email templates using stored user data
   - Export functions (CSV injection via stored data)
   - Log viewers rendering stored log entries

### Example: CSV Injection

```
User submits name: "=CMD('calc')!A1"
Stored in database as-is (safe for SQL)
Admin exports user list to CSV
Excel opens CSV, runs formula in name field
```

---

## Worked Example: Node.js Express App

**Target code:**
```javascript
app.get('/download', (req, res) => {
  const filename = req.query.file;
  const filepath = path.join(UPLOAD_DIR, filename);
  if (!fs.existsSync(filepath)) {
    return res.status(404).send('Not found');
  }
  res.download(filepath);
});
```

**Analysis:**

1. **Source**: `req.query.file` -- user-controlled query parameter
2. **Sink**: `res.download(filepath)` -- file system read + send to client
3. **Path**: `req.query.file` -> `filename` -> `path.join(UPLOAD_DIR, filename)` -> `filepath` -> `res.download(filepath)`
4. **Sanitization**: NONE. `path.join` normalizes but doesn't prevent traversal.
5. **Exploit**: `GET /download?file=../../etc/passwd`
   - `path.join('/uploads', '../../etc/passwd')` = `/etc/passwd`
   - `fs.existsSync('/etc/passwd')` = true
   - `res.download('/etc/passwd')` = file contents sent to attacker
6. **Fix**: resolve the path and verify it starts with the upload directory:
   ```javascript
   const resolved = path.resolve(UPLOAD_DIR, filename);
   if (!resolved.startsWith(path.resolve(UPLOAD_DIR))) {
     return res.status(400).send('Invalid filename');
   }
   ```

---

## Worked Example: Python Flask API

**Target code:**
```python
@app.route('/search')
def search():
    query = request.args.get('q', '')
    sort = request.args.get('sort', 'name')
    results = db.execute(
        f"SELECT * FROM products WHERE name LIKE '%{query}%' ORDER BY {sort}"
    )
    return jsonify([dict(r) for r in results])
```

**Analysis:**

1. **Sources**: `request.args.get('q')` and `request.args.get('sort')`
2. **Sink**: `db.execute()` with f-string interpolation -- SQL injection
3. **Two injection points:**
   - `query` in LIKE clause -- classic SQLi, break out of string context
   - `sort` in ORDER BY -- can't parameterize identifiers, needs allowlist
4. **Sanitization**: NONE
5. **Exploit (query)**: `GET /search?q=' UNION SELECT username,password,null FROM users--`
6. **Exploit (sort)**: `GET /search?q=test&sort=CASE WHEN (SELECT substring(password,1,1) FROM users WHERE username='admin')='a' THEN name ELSE price END`
7. **Fix**:
   ```python
   ALLOWED_SORTS = {'name', 'price', 'created_at'}
   sort = request.args.get('sort', 'name')
   if sort not in ALLOWED_SORTS:
       sort = 'name'
   results = db.execute(
       "SELECT * FROM products WHERE name LIKE :q ORDER BY " + sort,
       {"q": f"%{query}%"}
   )
   ```
