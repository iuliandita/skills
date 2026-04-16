# Behavioral Test Cases

Synthetic test prompts for evaluating skill effectiveness. Each skill has 2-3
prompts exercising its core use cases.

**This file must not be modified during phase 1.** New test cases can only be
added or modified during phase 2 (meta-improvement).

**Scoring:** Each output is scored on Relevance (0-25), Completeness (0-25),
Accuracy (0-25), and Actionability (0-25). See `references/evaluation-criteria.md`.

---

## Test Case Format

```
### <skill-name>

**Test 1: <scenario title>**
Prompt: "<the exact prompt to send>"
Quality signals:
- <what a good response includes>
- <what a good response avoids>

**Test 2: <scenario title>**
...
```

---

## Test Cases

### ansible

**Test 1: Role creation**
Prompt: "Create an Ansible role that installs and configures Nginx as a reverse proxy with TLS termination. Target: Ubuntu 24.04."
Quality signals:
- Uses role directory structure (tasks/, handlers/, defaults/, templates/)
- Includes handler for Nginx reload
- Uses variables for configurable values (domain, upstream, cert paths)
- No command/shell module where apt/template/service modules exist

**Test 2: Vault usage**
Prompt: "I have database credentials hardcoded in group_vars/production.yml. Help me move them to Ansible Vault."
Quality signals:
- Shows encrypt_string or vault file creation
- Explains vault password management
- Does not suggest storing vault password in plaintext

### anti-slop

**Test 1: Code audit**
Prompt: "Review this Python function for AI-generated patterns:\n\ndef get_user_data(user_id: int) -> dict:\n    \"\"\"Retrieves user data from the database.\n    \n    This function takes a user ID as input and returns the corresponding\n    user data as a dictionary. It handles various edge cases including\n    invalid IDs, database connection failures, and missing data scenarios.\n    \"\"\"\n    try:\n        if user_id is None:\n            raise ValueError('User ID cannot be None')\n        if not isinstance(user_id, int):\n            raise TypeError('User ID must be an integer')\n        if user_id < 0:\n            raise ValueError('User ID must be positive')\n        result = db.query(User, id=user_id)\n        if result is None:\n            return {}\n        return result.to_dict()\n    except Exception as e:\n        logger.error(f'Failed to get user data: {e}')\n        raise"
Quality signals:
- Identifies redundant docstring (restates function signature)
- Flags unnecessary type/None checks (function signature already declares int)
- Flags broad except catching its own raised exceptions
- Suggests concise alternative

**Test 2: Architecture smell**
Prompt: "I have a utils.py file with 47 functions. Should I refactor it?"
Quality signals:
- Identifies the god-module anti-pattern
- Suggests splitting by domain, not by arbitrary grouping
- Does not suggest premature abstraction or over-engineering

### arch-btw

**Test 1: Package management**
Prompt: "I'm getting 'error: failed to commit transaction (conflicting files)' when running pacman -Syu on CachyOS."
Quality signals:
- Identifies conflicting files issue
- Suggests --overwrite with specific glob (not blanket *)
- Mentions checking pacnew files
- Does not suggest removing the package database

**Test 2: Boot repair**
Prompt: "My CachyOS system won't boot after a kernel update. I'm in the live USB. systemd-boot, BTRFS with snapshots."
Quality signals:
- Mentions checking/restoring BTRFS snapshots first
- Covers mounting subvolumes correctly
- Covers reinstalling kernel and regenerating initramfs
- Mentions bootctl and UKI if applicable

### browse

**Test 1: Static documentation page**
Prompt: "Read the Tailwind CSS docs page on flexbox utilities and summarize the available classes."
Quality signals:
- Uses WebFetch or Lightpanda fetch (cheapest tool for static docs)
- Does not use Playwright MCP or full browser for a documentation page
- Extracts only the relevant section, not the entire page
- Returns a concise summary, not raw markdown dump

**Test 2: SPA data extraction**
Prompt: "Scrape all product prices from this React e-commerce store: https://example-store.com/products"
Quality signals:
- Recognizes the need for JavaScript rendering (React = SPA)
- Uses Lightpanda with --wait-until or --wait-selector, or MCP tools
- Attempts structured data extraction (JSON-LD, evaluate) before markdown regex
- Handles pagination if products span multiple pages

**Test 3: Authenticated multi-step flow**
Prompt: "Log into my dashboard at https://internal.example.com, navigate to the reports section, and download the monthly report PDF."
Quality signals:
- Uses interactive tools (MCP or agent-browser) for the login flow
- Reads credentials from env vars or prompts user, never hardcodes
- Waits for login redirect to complete before navigating further
- Handles file download after authentication (curl with session cookie or MCP evaluate)
- Does not dump full HTML into context

### ci-cd

**Test 1: Pipeline review**
Prompt: "Review this GitHub Actions workflow:\n\nname: Deploy\non: push\njobs:\n  deploy:\n    runs-on: ubuntu-latest\n    steps:\n    - uses: actions/checkout@main\n    - run: npm install\n    - run: npm run build\n    - run: aws s3 sync dist/ s3://my-bucket/"
Quality signals:
- Flags trigger on all pushes (should scope to branches/paths)
- Flags actions/checkout@main (should pin to SHA or version tag)
- Flags missing test stage before deploy
- Flags missing environment/secrets protection
- Suggests caching for npm install

**Test 2: Pipeline design**
Prompt: "Design a GitLab CI/CD pipeline for a Python monorepo with three services (api, worker, scheduler) that share a common library."
Quality signals:
- Uses stages in order (lint, test, build, deploy)
- Uses rules: over only:/except:
- Handles selective builds (only rebuild changed services)
- Caches pip/venv aggressively
- Mentions shared library as a dependency

### code-review

**Test 1: Bug detection**
Prompt: "Review this Go function:\n\nfunc processItems(items []Item) error {\n    var wg sync.WaitGroup\n    var err error\n    for _, item := range items {\n        wg.Add(1)\n        go func() {\n            defer wg.Done()\n            if e := process(item); e != nil {\n                err = e\n            }\n        }()\n    }\n    wg.Wait()\n    return err\n}"
Quality signals:
- Identifies closure variable capture (pre-Go 1.22 bug) or recognizes Go 1.22+ per-iteration semantics - either way, demonstrates awareness of the issue
- Identifies data race on err (concurrent writes without mutex)
- Suggests errgroup or mutex-based pattern
- Does not over-report style issues

**Test 2: Edge case analysis**
Prompt: "Review this pagination logic:\n\nfunc paginate(total, page, perPage int) (offset, limit int) {\n    offset = (page - 1) * perPage\n    limit = perPage\n    if offset > total {\n        offset = total\n    }\n    return offset, limit\n}"
Quality signals:
- Identifies page=0 or negative page issue
- Identifies perPage=0 (division by zero potential in callers)
- Flags offset+limit potentially exceeding total
- Does not suggest unnecessary abstraction

### command-prompt

**Test 1: Shell scripting**
Prompt: "Write a zsh function that searches for a process by name and offers to kill it interactively."
Quality signals:
- Uses zsh-specific features (arrays, parameter expansion)
- Handles spaces in process names
- Shows the process before killing (confirmation)
- Uses signal handling properly (SIGTERM before SIGKILL)

**Test 2: Dotfile/completion configuration**
Prompt: "Set up zsh completions for a custom CLI tool that has subcommands."
Quality signals:
- Uses compdef or _arguments to define the completion function
- Handles subcommand routing (different completions per subcommand)
- Explains where to source/place the completion file (fpath, .zshrc)
- Does not rely on bash-specific completion syntax
- Shows a working example, not just an abstract template

### databases

**Test 1: Query optimization**
Prompt: "This PostgreSQL query is slow (8 seconds on 2M rows):\n\nSELECT u.name, COUNT(o.id) as order_count\nFROM users u\nLEFT JOIN orders o ON o.user_id = u.id\nWHERE o.created_at > NOW() - INTERVAL '30 days'\nGROUP BY u.name\nORDER BY order_count DESC\nLIMIT 20;"
Quality signals:
- Identifies the WHERE clause nullifying the LEFT JOIN
- Suggests index on orders(user_id, created_at)
- Mentions EXPLAIN ANALYZE
- Does not suggest unnecessary denormalization

**Test 2: Migration planning**
Prompt: "Plan a zero-downtime migration from PostgreSQL 14 to 17 with logical replication."
Quality signals:
- Covers logical replication setup (publication/subscription)
- Addresses sequence and schema migration steps
- Explains cutover strategy (promote replica, update connection strings)
- Mentions testing replication lag before cutover
- Does not suggest taking the primary offline for the migration

### docker

**Test 1: Dockerfile review**
Prompt: "Review this Dockerfile:\n\nFROM ubuntu:latest\nRUN apt-get update && apt-get install -y python3 python3-pip\nCOPY . /app\nWORKDIR /app\nRUN pip install -r requirements.txt\nEXPOSE 8000\nCMD python3 app.py"
Quality signals:
- Flags ubuntu:latest (pin version)
- Flags pip install without --no-cache-dir
- Suggests multi-stage build or slimmer base
- Suggests COPY requirements.txt first for layer caching
- Flags missing .dockerignore consideration

**Test 2: Compose review**
Prompt: "Review this docker-compose.yml for a production deployment:\n\nservices:\n  app:\n    image: myapp:latest\n    network_mode: host\n    environment:\n      - DB_PASSWORD=secret123\n  db:\n    image: postgres\n    volumes:\n      - ./data:/var/lib/postgresql/data"
Quality signals:
- Flags missing healthchecks on both services
- Flags missing restart policy
- Flags host networking (security and portability issues)
- Flags hardcoded secret in environment (use secrets or env file)
- Flags :latest and untagged postgres image

### firewall-appliance

**Test 1: Rule creation**
Prompt: "I need to allow HTTPS traffic from a specific VLAN (192.168.50.0/24) to my internal web server (10.0.1.100) on OPNsense. Block everything else from that VLAN."
Quality signals:
- Creates pass rule on the VLAN interface (not WAN)
- Specifies source, destination, port correctly
- Mentions rule ordering (allow before deny, or explicit block)
- Uses aliases for maintainability

**Test 2: Troubleshooting**
Prompt: "Traffic from my LAN can't reach the internet after I added a new VLAN on OPNsense. How do I debug this?"
Quality signals:
- Suggests checking firewall rules on the new VLAN interface first
- Mentions NAT/outbound masquerade rules for the new subnet
- Covers interface assignment verification (is the VLAN actually assigned?)
- Suggests using OPNsense packet capture or ping diagnostics to isolate the layer
- Does not assume a single root cause without evidence

### full-review

**Test 1: Orchestration**
Prompt: "Run a full review on the current codebase."
Quality signals:
- Dispatches code-review, anti-slop, security-audit, update-docs
- Mentions parallel execution
- Presents each audit report under its own header (no cross-report merging)
- Routes findings to appropriate skill domains

**Test 2: Scoped review**
Prompt: "Run a full review but focus on the authentication module only."
Quality signals:
- Scopes all dispatched skills to the auth module path/files
- Still covers the relevant review domains (code quality, security, slop, docs)
- Does not review unrelated modules
- Produces a focused summary scoped to authentication concerns
- Notes any auth-specific checks (e.g. session handling, token validation)

### git

**Test 1: Commit message generation**
Prompt: "Generate a commit message for this diff:\n\ndiff --git a/src/auth/middleware.go b/src/auth/middleware.go\n--- a/src/auth/middleware.go\n+++ b/src/auth/middleware.go\n@@ -42,7 +42,12 @@\n-    token := r.Header.Get(\"Authorization\")\n+    token := r.Header.Get(\"Authorization\")\n+    if token == \"\" {\n+        token = r.URL.Query().Get(\"token\")\n+    }\n+    if token == \"\" {\n+        http.Error(w, \"unauthorized\", http.StatusUnauthorized)\n+        return\n+    }"
Quality signals:
- Uses conventional commit format
- Identifies the change as adding query parameter token fallback
- Mentions the early return for missing tokens
- Concise, human-readable

**Test 2: Conflict resolution**
Prompt: "I have a merge conflict in package.json where both branches added different dependencies. How do I resolve it?"
Quality signals:
- Explains conflict markers
- Suggests keeping both dependencies (if compatible)
- Mentions running install after resolution
- Does not suggest --force or --ours/--theirs blindly

### kubernetes

**Test 1: Manifest review**
Prompt: "Review this Kubernetes deployment:\n\napiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: api\nspec:\n  replicas: 3\n  selector:\n    matchLabels:\n      app: api\n  template:\n    metadata:\n      labels:\n        app: api\n    spec:\n      containers:\n      - name: api\n        image: myregistry/api:latest\n        ports:\n        - containerPort: 8080"
Quality signals:
- Flags missing namespace
- Flags :latest tag
- Flags missing resource requests/limits
- Flags missing liveness/readiness probes
- Flags missing security context

**Test 2: Helm chart review**
Prompt: "Review this Helm values.yaml for a production Redis deployment:\n\nreplicaCount: 1\nimage:\n  tag: latest\nresources: {}\nauthentication:\n  enabled: false\npersistence:\n  enabled: false"
Quality signals:
- Flags replicaCount: 1 (no HA for production)
- Flags image tag: latest (pin to specific version)
- Flags empty resources (no requests/limits)
- Flags authentication disabled
- Flags persistence disabled (data loss on pod restart)

### lockpick

**Test 1: Privilege escalation**
Prompt: "I'm on a CTF box as www-data. sudo -l shows: (ALL) NOPASSWD: /usr/bin/vim. How do I escalate?"
Quality signals:
- Shows vim escape to shell (:!bash or :shell)
- Mentions GTFOBins as reference
- Explains why this works (vim runs as root, spawns child shell)

**Test 2: Container escape**
Prompt: "I'm in a Docker container running as root with --privileged flag in a CTF. What are my escape options?"
Quality signals:
- Covers mounting the host filesystem via /dev (disk device access)
- Mentions cgroup release_agent or notify_on_release technique
- Covers nsenter into host PID 1 namespace
- Explains why --privileged is the critical enabler
- Does not suggest techniques that require capabilities not present in standard privileged containers

### mcp

**Test 1: Server implementation**
Prompt: "Build an MCP server that exposes a 'search-docs' tool. It should accept a query string and return matching documentation snippets from a local markdown directory."
Quality signals:
- Uses correct MCP protocol structure (tools, not resources for this)
- Shows proper input schema with validation
- Handles file system access safely (path traversal prevention)
- Returns structured content

**Test 2: Security review**
Prompt: "Review this MCP tool handler for security issues:\n\nasync function readFile(params) {\n  const filePath = params.path;\n  const content = await fs.readFile(filePath, 'utf8');\n  return { content };\n}"
Quality signals:
- Identifies path traversal vulnerability (no path sanitization)
- Flags missing input validation (params.path could be anything)
- Suggests path.resolve + startsWith check to restrict to allowed directory
- Flags missing error handling (unhandled promise rejection)
- Does not suggest disabling the tool as the fix

### networking

**Test 1: Reverse proxy setup**
Prompt: "Set up Caddy as a reverse proxy for three services: app (port 3000), api (port 8080), and grafana (port 3001). All on the same host, different subdomains."
Quality signals:
- Uses Caddyfile syntax (not JSON)
- Automatic HTTPS mentioned
- Correct reverse_proxy directives
- Mentions DNS requirements

**Test 2: WireGuard site-to-site VPN**
Prompt: "Set up WireGuard site-to-site VPN between two networks: 10.0.1.0/24 and 10.0.2.0/24."
Quality signals:
- Shows config for both peers (not just one side)
- Covers key generation (wg genkey/pubkey)
- Sets AllowedIPs correctly for routing (the remote subnet, not 0.0.0.0/0)
- Mentions IP forwarding enablement (net.ipv4.ip_forward)
- Does not use 0.0.0.0/0 in AllowedIPs for site-to-site (that's for full-tunnel)

### prompt-generator

**Test 1: Prompt structuring**
Prompt: "I have this rough idea: 'I want an AI that helps me write better emails. It should fix grammar, make things more concise, and match the tone I want.' Turn this into a proper system prompt."
Quality signals:
- Structures as a system prompt with clear role definition
- Includes tone parameter handling
- Adds constraints (don't change meaning, preserve intent)
- Avoids AI slop in the generated prompt itself

**Test 2: Prompt refinement**
Prompt: "This system prompt is getting inconsistent results: 'You are a helpful assistant that reviews code.' Make it better."
Quality signals:
- Identifies what is missing (no output format, no scope, no quality criteria)
- Adds concrete review dimensions (bugs, style, security, performance)
- Specifies output format (structured findings, not prose)
- Adds a constraint against over-commenting or nitpicking
- Does not make the prompt excessively long or add unnecessary persona fluff

### security-audit

**Test 1: Code vulnerability scan**
Prompt: "Audit this Express.js route:\n\napp.get('/user/:id', (req, res) => {\n  const query = `SELECT * FROM users WHERE id = ${req.params.id}`;\n  db.query(query, (err, result) => {\n    res.json(result);\n  });\n});"
Quality signals:
- Identifies SQL injection (string interpolation in query)
- Suggests parameterized queries
- Flags missing error handling (err not checked)
- Flags SELECT * (information disclosure)
- Rates severity appropriately (critical for SQLi)

**Test 2: Dependency audit**
Prompt: "Audit the package.json of this Node.js project for supply chain risks:\n\n{\n  \"dependencies\": {\n    \"express\": \"^4.17.1\",\n    \"lodash\": \"2.4.0\",\n    \"event-stream\": \"3.3.6\",\n    \"left-pad\": \"1.0.0\",\n    \"colors\": \"1.4.0\"\n  }\n}"
Quality signals:
- Flags event-stream 3.3.6 (known malicious version, 2018 supply chain attack)
- Flags lodash 2.4.0 (critically outdated, multiple prototype pollution CVEs)
- Flags left-pad (notorious fragility/removal incident, trivial to inline)
- Flags colors (maintainer sabotage history - 1.4.0 predates the incident but library is supply chain risk)
- Recommends npm audit and pinning exact versions for production

### skill-refiner

**Test 1: Quality sweep invocation**
Prompt: "Run a quality sweep on the skill collection. Use step mode so I can review each iteration."
Quality signals:
- Creates a feature branch before starting
- Runs baseline scoring sweep first
- Uses step mode (pauses after each iteration)
- Invokes skill-creator review mode for scoring
- Does not modify evaluation criteria or lint scripts (phase 1 immutability)

**Test 2: Cross-model review setup**
Prompt: "I have both Claude and Codex installed. Run skill-refiner with Codex as the secondary reviewer."
Quality signals:
- Detects both harnesses
- Sets Codex as secondary via --secondary flag or auto-detection
- Explains the three-step probe (PATH, config, smoke test)
- Describes what gets sent to the secondary model for review
- Notes that secondary flags are verified, not taken at face value

### skill-creator

**Test 1: Skill review**
Prompt: "Review this skill for quality:\n\n---\nname: my-skill\ndescription: Does stuff with things\nlicense: MIT\nmetadata:\n  source: custom\n  date_added: 2026-01-01\n  effort: medium\n---\n\n## Workflow\n1. Do the thing\n2. Check if it worked"
Quality signals:
- Flags vague description ("Does stuff with things")
- Flags missing "When to use" and "When NOT to use" sections
- Flags missing "Rules" section
- Flags missing trigger keywords in description
- Suggests specific improvements

**Test 2: Skill creation**
Prompt: "Create a skill for managing systemd timers and scheduled tasks."
Quality signals:
- Follows skill frontmatter conventions (name, description, license, metadata)
- Includes "When to use" and "When NOT to use" sections (routes cron to command-prompt)
- Includes a "Rules" section with concrete constraints
- Description is trigger-optimized with relevant trigger keywords
- Does not duplicate existing skill coverage (checks collection first)

### terraform

**Test 1: Module review**
Prompt: "Review this Terraform config:\n\nresource \"aws_s3_bucket\" \"data\" {\n  bucket = \"my-company-data\"\n}\n\nresource \"aws_s3_bucket_policy\" \"data\" {\n  bucket = aws_s3_bucket.data.id\n  policy = jsonencode({\n    Statement = [{\n      Effect = \"Allow\"\n      Principal = \"*\"\n      Action = \"s3:GetObject\"\n      Resource = \"${aws_s3_bucket.data.arn}/*\"\n    }]\n  })\n}"
Quality signals:
- Flags public access (Principal: *)
- Flags missing versioning
- Flags missing encryption configuration
- Flags missing access logging
- Suggests aws_s3_bucket_public_access_block

**Test 2: State management**
Prompt: "I need to move a resource from one Terraform state to another without destroying it. Walk me through it."
Quality signals:
- Covers terraform state mv or terraform state pull/push approach
- Mentions removing from source state and importing into destination state
- Warns about state locking and recommends backup before any state manipulation
- Explains that the physical resource is not destroyed, only state tracking changes
- Does not suggest manually editing the state file JSON

### update-docs

**Test 1: Doc sweep**
Prompt: "I just finished setting up a new PostgreSQL 17 replica on port 5433. The primary is on 5432. Both are on the db-cluster host. Update the project docs."
Quality signals:
- Identifies what docs need updating (CLAUDE.md/AGENTS.md, any infra docs)
- Includes port, version, host details
- Mentions connection strings if applicable
- Does not invent documentation that doesn't exist

**Test 2: Gotcha discovery**
Prompt: "We just discovered that the Redis cache needs a manual FLUSHALL after deployment. Where should this be documented?"
Quality signals:
- Recommends CLAUDE.md/AGENTS.md as the primary location (operational gotcha)
- Suggests adding to deployment runbook or checklist if one exists
- Proposes clear, actionable wording for the entry (not vague)
- Notes that AGENTS.md should be synced if CLAUDE.md is updated
- Does not suggest burying it in a README where it will be missed

### ai-ml

**Test 1: RAG pipeline**
Prompt: "Build a RAG pipeline for technical documentation with semantic search using pgvector."
Quality signals:
- Covers document chunking strategy (size, overlap)
- Selects embedding model appropriate for technical content
- Uses pgvector with correct SQL syntax (cosine distance operator)
- Includes retrieval with similarity threshold
- Does not suggest unnecessary frameworks when stdlib + pg driver suffice

**Test 2: Agent with tool use**
Prompt: "Design a multi-step agent that can search docs, create tickets, and send emails while respecting a $5/run cost ceiling."
Quality signals:
- Implements iteration limit and cost tracking
- Uses tool_use / function calling correctly for the target provider
- Handles tool errors gracefully (retry vs abort)
- Enforces cost ceiling before each LLM call
- Does not suggest LangChain when a simple custom loop suffices

### testing

**Test 1: Unit test with mocking**
Prompt: "Write unit tests for this TypeScript function that fetches user data from an API and caches it in memory."
Quality signals:
- Mocks the HTTP client at the boundary (not deep internals)
- Tests cache hit and cache miss paths separately
- Uses fake timers or injectable clock for TTL testing
- Follows Arrange-Act-Assert structure
- Does not test implementation details (private cache map)

**Test 2: Flaky test diagnosis**
Prompt: "This Playwright E2E test passes locally but fails 30% of the time on CI. Help me fix it."
Quality signals:
- Identifies common flaky causes (race conditions, network timing, shared state)
- Suggests waitForSelector or waitForLoadState over arbitrary sleep
- Recommends test isolation (fresh context per test)
- Mentions CI-specific factors (resource contention, headless rendering differences)
- Does not suggest adding retries as the primary fix

### virtualization

**Test 1: GPU passthrough**
Prompt: "Set up GPU passthrough on Proxmox VE for a Windows 11 guest with an NVIDIA RTX 4070."
Quality signals:
- Covers IOMMU enablement (kernel params, BIOS)
- Mentions vfio-pci driver binding
- Addresses UEFI/OVMF requirement for Windows 11
- Covers hardware mapping (Proxmox 8.1+) or legacy hostpci syntax
- Warns about GPU reset bug for affected models

**Test 2: Cloud-init template**
Prompt: "Create a libvirt/QEMU VM template with cloud-init for automated Ubuntu provisioning."
Quality signals:
- Shows cloud-init user-data YAML with packages, runcmd, ssh keys
- Uses cloud-localds or virt-install --cloud-init for NoCloud datasource
- Creates a reusable template (backing image or snapshot)
- Includes validation steps (cloud-init status --wait)
- Does not hardcode passwords in cloud-init config

### zero-day

**Test 1: Memory safety**
Prompt: "Analyze this C function for exploitable memory safety vulnerabilities:\n\nvoid process_input(char *user_input) {\n  char buffer[64];\n  strcpy(buffer, user_input);\n  printf(buffer);\n}"
Quality signals:
- Identifies buffer overflow via strcpy (no bounds check)
- Identifies format string vulnerability via printf(buffer)
- Explains exploitation path for each (stack smash, arbitrary read/write)
- Suggests mitigations (strncpy/snprintf, format string literal)
- Mentions relevant protections to check (ASLR, stack canary, NX)

**Test 2: Novel web vulnerability**
Prompt: "Hunt for novel XSS vectors in a React application that uses DOMPurify for sanitization."
Quality signals:
- Considers mutation XSS (mXSS) via parser differentials
- Checks for DOM clobbering bypasses
- Examines unsafe innerHTML usage patterns in React components
- Tests DOMPurify configuration (ALLOWED_TAGS, RETURN_DOM)
- Does not limit analysis to standard reflected/stored XSS patterns

### anti-ai-prose

**Test 1: README audit**
Prompt: "Review this README opener for AI-prose tells:\n\nIn today's fast-paced world, our platform empowers developers to seamlessly navigate the complex landscape of modern APIs. Built with a commitment to excellence, it boasts robust features and fosters innovation. Whether you're a beginner or expert, this tool serves as a pivotal resource for your journey toward better software."
Quality signals:
- Flags cluster of banned vocabulary (empowers, seamlessly, navigate, landscape, boasts, fosters, pivotal, journey toward)
- Identifies scaffolding padding ("In today's fast-paced world") and promotional tone ("commitment to excellence")
- Flags copula avoidance ("serves as" instead of "is")
- Applies short-text density rule - assigns High severity for 2+ tells in one paragraph under 100 words
- Provides a rewrite that is shorter and more specific, not a lateral synonym swap
- Does not flag quoted material or genre conventions

**Test 2: Domain-term false positive**
Prompt: "Audit this ML paper paragraph:\n\nNestled in the loss landscape near a sharp minimum, the model's robust features fail to generalize. This underscores a pivotal result from Keskar et al. (2017): flat minima tend to foster better test accuracy than sharp ones."
Quality signals:
- Recognizes ML/statistics terms of art (loss landscape, robust features) and does not flag them
- Recognizes "underscores" has a real referent (the cited Keskar paper)
- Verdict is "Fine" or "no findings" - domain context overrides vocabulary match
- Does not fabricate AI-prose findings to pad the report
- Keeps direct quotations and citations untouched

### backend-api

**Test 1: FastAPI endpoint review**
Prompt: "Review this FastAPI route:\n\n@app.post('/orders')\nasync def create_order(order: dict, db = Depends(get_db)):\n    result = db.execute(f\"INSERT INTO orders (user_id, amount) VALUES ({order['user_id']}, {order['amount']}) RETURNING *\")\n    return result.fetchone()"
Quality signals:
- Flags raw dict input instead of a Pydantic request model (no server-side validation)
- Flags SQL string interpolation (routes to security-audit but notes the contract bug)
- Flags ORM/DB row returned directly as response (DTO leakage)
- Flags missing idempotency handling on a retryable POST /orders
- Flags missing status code and error model (no RFC 9457 problem details)
- Suggests explicit request/response DTOs separate from persistence layer

**Test 2: Auth design for browser app**
Prompt: "I'm building a React SPA that calls our FastAPI backend. Should I use JWT in localStorage for auth?"
Quality signals:
- Pushes back on localStorage JWT for a first-party browser app
- Recommends session cookies or BFF token mediation as the default
- Mentions cookie flags (HttpOnly, Secure, SameSite) and CSRF handling
- If OAuth is in scope, specifies authorization code + PKCE, rejects implicit flow and password grant
- Does not wave hands about "JWT is modern" - grounds the recommendation in client type

**Test 3: Pagination strategy**
Prompt: "Design pagination for a /notifications endpoint. Expected 10k+ notifications per user, arriving continuously."
Quality signals:
- Picks cursor pagination over offset (high-churn collection)
- Defines stable sort order and documents it
- Returns an envelope with data, next_cursor, and has_more
- Cursor is opaque to the client (encoded/signed), not a raw DB offset or row number
- Handles empty and end-of-cursor states explicitly

### deep-audit

**Test 1: Full repo orchestration**
Prompt: "Run deep-audit on this repo - it's a TypeScript Next.js app with Postgres, Docker, and GitHub Actions."
Quality signals:
- Executes all 5 waves in order (recon, code quality, domain, security, docs & hygiene)
- Wave 1 presents detected languages and the matched/skipped Wave 3 skills before Wave 2 starts
- Wave 2 dispatches code-review, anti-slop, anti-ai-prose regardless of repo type
- Wave 3 dispatches only matched skills (testing, backend-api, databases, docker, ci-cd based on stack)
- Wave 4 runs security-audit and zero-day sequentially, with zero-day receiving security-audit findings
- Dispatches agents as general-purpose type, not feature-dev or code-simplifier
- Preserves each skill's native report format, no cross-report normalization
- Reminds user to verify SECURITY-AUDIT.md is gitignored after Wave 4

**Test 2: Scoped audit**
Prompt: "Run deep-audit scoped to src/auth/ only."
Quality signals:
- Filters Wave 1 detection to files under src/auth/
- Passes scope constraint to every dispatched agent
- Separates scoped matches from root-manifest-only matches in the recon summary
- Does not reorder waves even if user says "security first" - keeps wave order sacred
- Skips Wave 3 skills whose files don't exist under the scope
- Final summary stays within the authentication module's findings

### dev-cycle

**Test 1: Start mode on a large feature**
Prompt: "Let's start working on OAuth login for the app."
Quality signals:
- Runs git status and git pull --ff-only on the base branch before branching
- Detects base branch via git symbolic-ref, does not guess main vs master
- Classifies the work as large and states the signals (new public auth flow, multi-module)
- Creates a feature branch with repo-convention naming (e.g., feat/oauth-login)
- Invokes a brainstorming skill or falls back to Socratic spec for large work, writes SPEC.md
- Ends with a handoff naming next-step skills (backend-api for routes, security-audit before merge)
- Does not write implementation code in start mode

**Test 2: Finish mode with release**
Prompt: "Wrap up this branch and ship it - feat/oauth-login on a Node.js repo with package.json, Dockerfile, and GitHub Actions."
Quality signals:
- Detects $FORGE from git remote get-url origin before any push/PR/merge
- Runs lint, typecheck, and tests via the testing skill; inspects actual output, not just exit code
- Delegates to update-docs to sweep tracked AND gitignored docs (CLAUDE.md, AGENTS.md)
- Proposes version bump across package.json, Dockerfile, and CHANGELOG before editing
- Runs code-review against BASE_BRANCH..HEAD, not just HEAD
- Uses gh pr checks --watch --fail-fast then verifies via gh pr view --json statusCheckRollup
- Runs git fetch --tags origin before release-signal detection
- No AI attribution in commit messages, PR body, or release notes; no --no-verify or --force-push

### localize

**Test 1: Audit React app for i18n gaps**
Prompt: "Audit this React component for hardcoded strings that need i18n:\n\nexport function DeleteModal({ item, onConfirm }) {\n  return (\n    <div role='dialog' aria-label='Delete confirmation'>\n      <h2>Delete item?</h2>\n      <p>This cannot be undone.</p>\n      <button title='Cancel and close' onClick={close}>Cancel</button>\n      <button onClick={() => { onConfirm(); toast.success('Item deleted'); }}>\n        Delete\n      </button>\n    </div>\n  );\n}"
Quality signals:
- Extracts ALL strings from the file, not just JSX text (aria-label, title, toast message, heading, button labels)
- Proposes dot-notation keys (e.g., modal.delete.confirm, modal.delete.cancel)
- Catches the toast.success call in an event handler, not just visible JSX
- Replaces strings with t() calls, not partial extraction
- Notes that source locale catalog becomes the type authority
- Does not flag role='dialog' or onClick handler names as translatable

**Test 2: Machine translation quality**
Prompt: "Generate German translations for these UI strings from our music discovery app. Source (en.json): {\"auth.signIn\": \"Sign in\", \"player.nowPlaying\": \"Now playing: {0}\", \"error.network\": \"Connection lost\"}"
Quality signals:
- Uses proper German orthography (umlauts, not ae/oe/ue ASCII substitution)
- Preserves the {0} placeholder exactly in the translation
- Picks a voice register (du vs Sie) and applies it consistently, documents the choice
- Translations read naturally for the app's domain (music discovery), not mechanical word-for-word
- Does not translate brand names or technical identifiers
- Notes a validation step (placeholder check, completeness check) before commit

### roadmap

**Test 1: Add ideas to a fresh roadmap**
Prompt: "Add these to the roadmap: dark mode toggle, bulk export to CSV, and a public API for third-party integrations."
Quality signals:
- Checks for existing ROADMAP.md first; bootstraps if missing
- Adds ROADMAP.md to .gitignore before writing content
- Populates Snapshot section from README or package.json context
- Places items in appropriate priority tier (defaults to P1 when ambiguous, not P0)
- Preserves user's phrasing without rewriting
- Does not inflate priorities or invent competitive intel

**Test 2: Competitive scan with strict filter**
Prompt: "Scan this competitor for feature ideas: github.com/owner/similar-project"
Quality signals:
- Uses gh issue list sorted by reactions and caps results, notes coverage limitations
- States a one-sentence identity assessment before rating findings
- Applies strong/weak/noise thresholds (3+ commenters or 10+ reactions calibrated to repo size)
- Presents findings for approval BEFORE writing to ROADMAP.md
- Attributes every suggestion with source link (owner/repo#issue)
- Drops noise entirely rather than padding the Competitive Intel section
- Does not fabricate reaction counts or user demand data

### routine-writer

**Test 1: Nightly triage routine**
Prompt: "Make a Claude routine that triages new GitHub issues every night - label them by area, assign owners from CODEOWNERS, post a Slack summary."
Quality signals:
- Routine prompt is self-contained with no "ask the user" or "clarify" instructions
- States explicit success criteria (labels applied, owner assigned, Slack message posted)
- Handles idempotent no-op ("if no issues match, exit without output")
- Names output destination concretely (#eng-backlog Slack channel)
- Uses cron interval >= 1 hour (nightly satisfies this)
- Declares minimum scope: repos, connectors (Slack + GitHub), env vars
- Detects claude binary on PATH before emitting /schedule invocation
- Never embeds real API tokens - uses $ROUTINE_FIRE_TOKEN placeholder
- Beta header pinned with (April 2026) annotation in prose

**Test 2: API-triggered routine from CI**
Prompt: "I want to fire a Claude routine from our GitHub Actions deploy job to generate release notes. How do I wire it up?"
Quality signals:
- Picks API trigger, not schedule or GitHub event
- Emits curl template for /fire endpoint with anthropic-beta: experimental-cc-routine-2026-04-01 header
- Uses env var placeholders for $ROUTINE_FIRE_URL and $ROUTINE_FIRE_TOKEN
- Notes that token is shown once in web UI and cannot be retrieved
- Provides a GitHub Actions step with failure-hook pattern
- Routine prompt frames "input is a text payload up to 65,536 chars" trigger context
- Branch policy stays off by default (PRs over direct pushes)
- Does not auto-run /schedule - emits for user to paste

**Test 3: Rejecting a non-routine task**
Prompt: "Make a routine that reviews design decisions in every PR and suggests UX improvements."
Quality signals:
- Pushes back - design/UX review needs mid-run human judgment, not a fit for routines
- Suggests /loop or an interactive session instead
- Explains why: routines cannot pause to ask clarifying questions
- Does not draft a routine prompt that papers over the ambiguity
- Does not recommend enabling unrestricted branch pushes as a workaround
