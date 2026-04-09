# Security Audit: Grep Patterns

Consolidated search patterns for manual audit passes. Use the Grep tool with these patterns - don't shell out to grep/rg.

## Secret Scanning Fallback (Pass 1)

Use these only when betterleaks/gitleaks/trufflehog are all unavailable.

| Pattern | What it finds | File types |
|---------|---------------|------------|
| `(api[_-]?key\|apikey\|secret[_-]?key)\s*[:=]\s*["'][^\s"']{8,}` | Hardcoded API keys | `*.ts`, `*.js`, `*.py`, `*.go` |
| `password\s*[:=]\s*["'][^\s"']{8,}` | Hardcoded passwords | `*.ts`, `*.js`, `*.py`, `*.go`, `*.yml` |
| `(token\|bearer)\s*[:=]\s*["'][^\s"']{16,}` | Hardcoded tokens | `*.ts`, `*.js`, `*.py`, `*.go` |
| `-----BEGIN (RSA\|EC\|DSA\|OPENSSH) PRIVATE KEY` | Private keys | All files |
| `(AKIA\|ASIA)[A-Z0-9]{16}` | AWS access key IDs | All files |
| `ghp_[a-zA-Z0-9]{36}\|github_pat_` | GitHub personal access tokens | All files |
| `sk-[a-zA-Z0-9]{20,}` | OpenAI / Stripe secret keys | All files |
| `mongodb(\+srv)?://[^/\s]+:[^@\s]+@` | Connection strings with embedded passwords | All files |
| `postgres(ql)?://[^/\s]+:[^@\s]+@` | Postgres connection strings with passwords | All files |

Also check git history: `git log --all --diff-filter=A - '*.env*'`

## Authentication & Authorization (Pass 4)

| Pattern | What it finds | Flag as |
|---------|---------------|---------|
| `bypass\|whitelist\|allowlist\|skip.*auth\|no.*auth\|public.*route` | Auth bypass indicators | Review each match |
| `setup_mode\|isAdmin.*req\|role.*req\.body\|req\.query.*admin` | Client-controlled auth flags | High if trusted |
| `req\.params\.id\|req\.params\.userId\|c\.req\.param.*id` | Direct ID usage (IDOR risk) | Check if validated against session |
| `x-forwarded-for\|x-real-ip\|forwarded` (case-insensitive) | Header trust for auth decisions | High if used for auth |
| `startsWith.*api\|endsWith.*setup\|includes.*path` | Substring/suffix auth bypass patterns | Critical pattern |

## Injection & Input Validation (Pass 5)

### Command Injection
| Pattern | Context |
|---------|---------|
| `exec\(\|execSync\|spawn\|child_process\|subprocess` | Shell execution |
| `shell:\s*true\|shell=True` | Explicit shell mode |
| `\$\{.*req\|f".*{.*input\|f".*{.*param` | String interpolation with user input in shell context |

### Path Traversal
| Pattern | Context |
|---------|---------|
| `\.\.\/\|\.\.\\\\` | Literal traversal sequences |
| `path\.join.*req\|path\.resolve.*req\|os\.path\.join.*request` | Path construction with user input |
| `readFile.*param\|writeFile.*param\|createReadStream.*req` | File I/O with user-controlled paths |
| `extractall\|unzip\|yauzl\|archiver` | Zip handling (check for Zip Slip) |
| `rmtree\|rimraf\|rm.*-rf\|fs\.rm` | Recursive delete candidates |

### SSRF
| Pattern | Context |
|---------|---------|
| `fetch\(\|axios\.\|got\(\|http\.get\|http\.request\|undici` | HTTP client usage |
| `new URL.*req\|new URL.*param\|new URL.*body` | URL construction from user input |
| `redirect\|followRedirect\|maxRedirects` | Redirect following config |

### SQL Injection
| Pattern | Context |
|---------|---------|
| `db\.execute\|\.query\(\|\.raw\(` | Raw query execution |
| `sql\`.*\$\{` | Template literal SQL with interpolation |
| `knex\.raw\|sequelize\.query\|prisma\.\$queryRaw` | ORM raw query methods |

### XSS (unsafe HTML rendering patterns)
| Pattern | Context |
|---------|---------|
| `dangerouslySetInner\|v-html\|innerHTML` | Unsafe HTML rendering |
| `javascript:\|data:text/html` | Dangerous URL schemes |
| `document\.write\|\.insertAdjacentHTML` | DOM manipulation |

### XML
| Pattern | Context |
|---------|---------|
| `parseXML\|DOMParser\|xml2js\|ElementTree\|etree\|lxml` | XML parsing |
| `resolveExternals\|loadExternalSubsets\|XMLReader` | External entity config |

## Cryptography & Data Protection (Pass 6)

| Pattern | What it finds |
|---------|---------------|
| `rejectUnauthorized.*false\|NODE_TLS_REJECT_UNAUTHORIZED` | TLS verification disabled |
| `console\.log.*password\|console\.log.*token\|console\.log.*secret\|console\.log.*key` | Secrets in logs |
| `Access-Control-Allow-Origin.*\*` | Permissive CORS |
| `httpOnly\|secure.*cookie\|sameSite` | Cookie security flags (absence is the finding) |
| `md5\|sha1\|sha256.*password\|sha-256.*hash` | Weak password hashing |
| `crypto\.createCipher[^I]\|DES\|RC4\|ECB` | Weak/deprecated crypto |

## Container & Infrastructure (Pass 7)

### Terraform
| Pattern | What it finds | File types |
|---------|---------------|------------|
| `"Action".*"\*"\|actions.*=.*\["\*"\]` | Wildcard IAM actions | `*.tf`, `*.json` |
| `"Resource".*"\*"\|resources.*=.*\["\*"\]` | Wildcard IAM resources | `*.tf`, `*.json` |
| `cidr_blocks.*0\.0\.0\.0/0\|ingress_cidr_blocks.*0\.0\.0\.0/0\|source_ranges.*0\.0\.0\.0/0` | Open ingress from internet | `*.tf` |
| `sensitive\s*=\s*false\|#.*sensitive` | Variables that should be sensitive | `*.tf` |
| `access_key\|secret_key\|password\s*=\s*"[^"$]` | Hardcoded credentials in TF | `*.tf` |
| `backend\s+"local"\|\.tfstate` | Local state (secrets in plaintext on disk) | `*.tf`, `.gitignore` |
| `encryption\s*=\s*false\|encrypted\s*=\s*false\|kms_key_id\s*=\s*""` | Encryption explicitly disabled | `*.tf` |
| `publicly_accessible\s*=\s*true\|public_access\|acl.*public` | Public cloud resources | `*.tf` |

### Ansible
| Pattern | What it finds | File types |
|---------|---------------|------------|
| `password:\s*[^{!\s]\|token:\s*[^{!\s]\|secret:\s*[^{!\s]` | Plaintext secrets (not vault/variable ref) | `*.yml`, `*.yaml` |
| `no_log:\s*false` | Explicitly disabled log suppression | `*.yml`, `*.yaml` |
| `shell:\|command:\|raw:` | Shell execution (check for user input) | `*.yml`, `*.yaml` |
| `ansible_become_password\|ansible_ssh_pass` | Plaintext auth in inventory | `*.ini`, `*.yml` |

### Docker Compose
| Pattern | What it finds | File types |
|---------|---------------|------------|
| `privileged:\s*true` | Privileged containers | `*.yml`, `*.yaml` |
| `network_mode:\s*host` | Host network mode | `*.yml`, `*.yaml` |
| `/var/run/docker\.sock` | Docker socket mount | `*.yml`, `*.yaml` |
| `volumes:.*/:\/[^d]` | Sensitive host path mounts (/, /etc, /root) | `*.yml`, `*.yaml` |

### Proxmox / LXC
| Pattern | What it finds | File types |
|---------|---------------|------------|
| `root@pam` | Root PAM auth in API calls (should use dedicated tokens) | `*.sh`, `*.py`, `*.tf`, `*.yml` |
| `PVEAdmin\|Administrator` | Overly broad Proxmox role assignment | `*.tf`, `*.yml`, `*.yaml` |
| `pm_api_token_secret\|api_token_secret` | Proxmox API secrets (check if encrypted/vaulted) | `*.tf`, `*.yml` |
| `unprivileged:\s*0\|privileged:\s*1\|privileged:\s*true` | Privileged LXC containers | `*.conf`, `*.tf`, `*.yml` |
| `verify_ssl.*false\|ssl_verify.*false\|insecure.*true` | TLS verification disabled for Proxmox API | `*.py`, `*.tf`, `*.yml` |

### Shell / Cloud-Init
| Pattern | What it finds | File types |
|---------|---------------|------------|
| `curl.*\|\s*bash\|wget.*\|\s*sh\|curl.*\|\s*sh` | Pipe-to-shell (no integrity check) | `*.sh`, `*.yaml`, `*.cfg` |
| `chmod\s+777\|chmod\s+-R\s+777` | World-writable permissions | `*.sh` |

## CI/CD & Supply Chain (Pass 8)

### CI/CD Workflows

*See pass 8 in the main audit skill for workflow-level checks.*

### Supply Chain: Image Pinning

| Pattern | What it finds | File types |
|---------|---------------|------------|
| `image:.*:latest` | Unpinned `:latest` tags in CI/container configs | `*.yml`, `*.yaml`, `*.tf` |
| `pull_policy:\s*always` | Always-pull policy (dangerous with unpinned tags) | `*.yml`, `*.yaml` |
| `tag:\s*["']?latest["']?` | `:latest` tags in Helm values or Terraform | `*.yml`, `*.yaml`, `*.tf` |
| `image:.*:[a-zA-Z0-9._-]+\s*$` | Image references with tag but no `@sha256:` digest | `*.yml`, `*.yaml` |
| `DOCKER_AUTH_CONFIG` | Registry credentials in CI config (check scope) | `*.yml`, `*.yaml` |
