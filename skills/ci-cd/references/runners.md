# CI/CD Runners: Install, Configure, Harden

Cross-platform reference for self-hosted CI runners. Covers the five implementations in
common use as of 2026:

| Runner | Platform | Language | Common executors |
|--------|----------|----------|------------------|
| `actions-runner` | GitHub Actions (self-hosted) | C# / .NET | shell (default), container via action |
| `gitlab-runner` | GitLab CI/CD | Go | shell, docker, docker-autoscaler, kubernetes, instance, ssh |
| `forgejo-runner` | Forgejo Actions | Go (forked from `act`) | docker, host (shell), LXC, docker-in-docker |
| `gitea-runner` (Gitea Runner, formerly `act_runner`) | Gitea Actions | Go (from `act`) | docker, host (shell) |
| `woodpecker-agent` | Woodpecker CI | Go | docker, kubernetes, local (shell) |

**Gitea Runner vs `forgejo-runner`**: both descend from the `act` project. Forgejo forked
in 2023 and the two have since diverged - different config defaults, different label syntax
edges, different registration APIs. They are not interchangeable; pick the one that matches
the forge you run. Gitea's runner was renamed from `act_runner` to Gitea Runner
(announced https://blog.gitea.com/release-of-runner-1.0.0/, 2026-05-05); Forgejo's
`forgejo-runner` is a separate project and was not renamed.

---

## Choosing an Executor

Before installing any runner, decide the isolation and concurrency model. This matters more
than which runner you pick.

### Two-axis decision matrix

| | Persistent (reused across jobs) | Ephemeral (one job, then destroyed) |
|-|--------------------------------|--------------------------------------|
| **Shell / host** | Fast, leaky. Solo/internal repos only. State leaks between jobs. | Rare (needs VM/machine recycling). macOS iOS builds sometimes. |
| **Container / pod** | Docker executor on a long-lived runner. Standard default. | Kubernetes executor, docker-autoscaler, `--ephemeral` flag. Correct default for untrusted code. |

**Rule of thumb**: if the repo is public or accepts PRs from outside your org, runners
**must** be ephemeral + isolated. Containerization alone is insufficient for privileged jobs. Non-ephemeral shell runners on public repos is the
single most common CI pwnage vector (documented extensively by Synacktiv, Sysdig).

### Shell vs Docker executor

| Aspect | Shell | Docker |
|--------|-------|--------|
| Isolation | None - jobs share the host filesystem, env, and installed tools | Per-job container, own filesystem layer |
| Setup cost | Install tools on host, manage versions manually | Pull image; tools baked in |
| Speed | Fastest (no container overhead) | Slower first run (image pull), comparable after warm cache |
| Caching | Ad-hoc (shared host caches are a leak risk) | Image layer cache + per-job volume mounts |
| Network | Host network | Container network (configurable) |
| macOS native builds (iOS) | **Required** - Docker on macOS is a Linux VM | Cannot build native macOS artifacts |
| Public repo safety | **Never** | Safe with `--ephemeral` + network egress controls |
| Debug ergonomics | SSH to host, run commands directly | `docker exec` into a failed job's container (harder on one-shot) |

Rule: shell for internal Linux/macOS builds where you control every commit; docker for
everything else.

### Docker-in-Docker (DinD) vs docker socket mount

When jobs need to build images or run containers themselves:

- **Socket mount** (`-v /var/run/docker.sock:/var/run/docker.sock`): fast, simple.
  **Warning**: jobs can control the host Docker daemon. Untrusted code can escape the
  runner in one step. Only for trusted internal pipelines.
- **DinD** (`dind` sidecar on port 2375/2376): per-job daemon. Privileged DinD is not a
  security boundary for untrusted jobs; isolate its host and use authenticated TLS networking.
- **rootless buildkit** (`buildx` with a rootless daemon): the 2026 default for image
  builds - no privileged containers, no socket mount, no DinD complexity.

---

## `gitlab-runner`

### Install

For container installs, set `GITLAB_RUNNER_IMAGE` to a reviewed version tag plus
manifest digest from the official registry. Do not use a mutable tag.

| OS | Command |
|----|---------|
| Debian/Ubuntu | `curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" \| sudo bash && sudo apt install gitlab-runner` |
| RHEL/Fedora | `curl -L ".../script.rpm.sh" \| sudo bash && sudo dnf install gitlab-runner` |
| Arch | `paru -S gitlab-runner` |
| macOS (Intel + Apple Silicon) | `brew install gitlab-runner && brew services start gitlab-runner` |
| Binary (any Linux) | Download from `gitlab-runner-linux-<arch>` release, `install -m 755 ... /usr/local/bin/gitlab-runner` |
| Docker | `docker run -d --name gitlab-runner --restart always -v /srv/gitlab-runner/config:/etc/gitlab-runner -v /var/run/docker.sock:/var/run/docker.sock "${GITLAB_RUNNER_IMAGE:?set to a reviewed tag@sha256 digest}"` |
| Kubernetes | Official Helm chart `gitlab/gitlab-runner` |

Linux packages register a `gitlab-runner` user and a systemd service. macOS `brew services`
registers a launchd agent under the installing user (not root - this matters for permissions).

### Register

```bash
# Interactive
sudo gitlab-runner register

# Interactive; enter the token through the prompt, not argv
sudo gitlab-runner register \
  --url https://gitlab.example.com \
  --executor docker \
  --docker-image "alpine:3.19" \
  --description "docker-runner-01" \
  --tag-list "docker,linux,amd64"
```

Tokens come from **Admin Area -> CI/CD -> Runners -> Register an instance runner** for
instance-scoped, or **Settings -> CI/CD -> Runners** per-group/project. GitLab 17+
deprecated the old "registration token" flow in favor of authentication tokens issued
per-runner - check your instance.

### Config location

`/etc/gitlab-runner/config.toml` (Linux/Docker) or `~/.gitlab-runner/config.toml` (macOS
user install, Windows). One file holds multiple runners. Example:

```toml
concurrent = 4
check_interval = 0

[[runners]]
  name = "docker-runner-01"
  url = "https://gitlab.example.com"
  token = "glrt-xxxxxxxxxxxxxxxxxxxx"
  executor = "docker"
  [runners.docker]
    image = "alpine:3.19"
    privileged = false
    volumes = ["/cache"]
    pull_policy = ["always"]
```

### Executor choice

- **shell** - runner user executes commands directly on the host. Fast, unsafe. Use for
  internal builds only.
- **docker** - per-job container. Default recommendation.
- **docker-autoscaler** - docker executor backed by a fleeting cloud plugin (AWS, GCP,
  Azure). Scales machines up/down per demand. Replaces the legacy docker-machine executor
  (deprecated in 16.x, removed in 18.x).
- **kubernetes** - pod per job. Use when you already run a k8s cluster. Scales beautifully
  but has the highest cold-start latency.
- **instance** - full host access, one runner per machine, for jobs that need root (kernel
  tests, hardware access).
- **ssh** - connects to an external box. Legacy; prefer docker-autoscaler or instance.

---

## `forgejo-runner`

### Install

| OS | Command |
|----|---------|
| Binary (Linux) | Download from `code.forgejo.org/forgejo/runner/releases/latest`, verify with `gpg`, `install -m 755 ... /usr/local/bin/forgejo-runner` |
| Binary (macOS) | Same, pick `darwin-arm64` or `darwin-amd64` |
| OCI container | `docker pull data.forgejo.org/forgejo/runner:<major>` (the prior `:13` target is unverified; check `https://data.forgejo.org/forgejo/-/packages/container/runner/versions` for the latest tag before pinning. Runs as uid 1000.) |
| Docker Compose | Reference compose file in upstream docs - pairs with a DinD sidecar |
| Kubernetes | Community Helm charts exist; no official chart yet |

No distro packages in the major repos as of 2026. Install is manual tarball / docker on
both Linux and macOS.

### Register

```bash
# Interactive
forgejo-runner register

# Interactive registration; provision verified file/environment input for automation
forgejo-runner register \
  --instance https://git.example.com \
  --name "runner-01" \
  --labels "docker:docker://node:20-bookworm,ubuntu-22.04:docker://node:20-bookworm"
```

Token from **Site Administration -> Actions -> Runners -> Create new runner** (instance
scope) or per-repo runner settings.

**Automated registration:** inspect the installed runner's help and official registration
API for protected environment/file input. Provision registration state through a secret
manager and mode-0600 files. Do not put tokens or shared registration secrets in argv.

### Config location

`config.yml` in the runner's working directory (wherever you run `forgejo-runner daemon`).
Generate with `forgejo-runner generate-config > config.yml`. Essentials:

```yaml
runner:
  file: .runner                    # state file - keep safe
  capacity: 1                      # concurrent jobs; raise for bigger boxes
  timeout: 3h
  labels:
    - docker:docker://node:20-bookworm
    - host

container:
  network: ""                      # auto-detect; set to "host" for host-network jobs
  privileged: false                # flip to true only if jobs need DinD
  options: ""
  workdir_parent: ""
  valid_volumes: []                # whitelist host paths jobs may mount

cache:
  enabled: true
  dir: ""                          # default: ./artifacts
```

### Executor choice

Backends are picked per-label via the `labels` list:

- `docker://<image>` - runs the job in a container from that image (default path)
- `host` - runs the job as shell commands on the runner host (no isolation)
- `lxc:<profile>` - Forgejo-only; runs inside an LXC container. Heavier than docker,
  lighter than a VM
- `docker-in-docker` (via privileged container + dind sidecar) - for jobs that build images

Forgejo exposes LXC as a first-class option that Gitea Runner does not. Useful
when you want kernel-level isolation without the cost of a full VM.

---

## Gitea Runner (Gitea)

Binary `gitea-runner`, repo https://gitea.com/gitea/runner, image `gitea/runner`. There is
no `act_runner` alias; older docs and scripts using `act_runner` refer to the same project
pre-rename. Version pins live in `references/target-versions.md`.

### Install

Set `GITEA_RUNNER_IMAGE` to a reviewed version tag plus manifest digest from the
official registry before using either container example.

| OS | Command |
|----|---------|
| Binary | Download from `gitea.com/gitea/runner/releases`, nightly from `dl.gitea.com/runner/` |
| Docker | `docker pull "${GITEA_RUNNER_IMAGE:?set to a reviewed tag@sha256 digest}"` (image `gitea/runner`) |
| Docker Compose | Example in upstream docs |

### Register

```bash
# Interactive
./gitea-runner register

# Interactive registration; provision verified file/environment input for automation
./gitea-runner register \
  --instance https://gitea.example.com \
  --name "runner-01" \
  --labels "ubuntu-latest:docker://node:20-bookworm,ubuntu-22.04:docker://node:20-bookworm"

# Ephemeral - exits after one job
./gitea-runner register --ephemeral ...
```

Tokens from **Site Administration -> Actions -> Runners** (instance), org settings, or
repo settings.

### Config location

Generate with `./gitea-runner generate-config > config.yaml`. Structure is nearly identical
to `forgejo-runner`'s; differences worth knowing:

- Default labels use `ubuntu-*` names directly (aligning with GitHub Actions expectations)
- Gitea Runner has a first-class `--ephemeral` flag on `register`; on `forgejo-runner`,
  use a verified single-job exit lifecycle plus fresh per-job host/container state.
  A concurrency limit or daemon restart alone is not ephemerality.

### Executor choice

Two backends: `docker://<image>` and `host`. No LXC support. For jobs that need to build
images, use docker socket mount (trusted pipelines only) or a DinD sidecar.

### Docker Compose pattern

```yaml
services:
  runner:
    image: ${GITEA_RUNNER_IMAGE:?set to a reviewed tag@sha256 digest}
    environment:
      GITEA_INSTANCE_URL: https://gitea.example.com
      GITEA_RUNNER_REGISTRATION_TOKEN: ${TOKEN}
      GITEA_RUNNER_NAME: runner-01
    volumes:
      - ./data:/data
      - /var/run/docker.sock:/var/run/docker.sock   # DANGEROUS for untrusted code
```

Swap the socket mount for a DinD sidecar on shared/public instances.

---

## `actions-runner` (GitHub Actions, self-hosted)

### Install

GitHub does not ship package manager installs. Runners are downloaded per-repo / org /
enterprise with a pre-baked URL that includes a short-lived token.

**Linux x64** (pattern - exact version and token from the GitHub UI under **Settings ->
Actions -> Runners -> New self-hosted runner**):

```bash
mkdir actions-runner && cd actions-runner
curl -o runner.tar.gz -L \
  "https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-linux-x64-2.322.0.tar.gz"
tar xzf runner.tar.gz
./config.sh \
  --url https://github.com/your-org/your-repo \
  --labels "linux,docker,self-hosted" \
  --ephemeral \
  --runnergroup default \
  --disableupdate
./run.sh
```

**macOS (Apple Silicon)**: identical flow, pick `osx-arm64` tarball. For Intel Macs, pick
`osx-x64`. Both require Xcode Command Line Tools (`xcode-select --install`) for most
iOS/macOS build pipelines.

### Service install

```bash
# Linux (systemd)
sudo ./svc.sh install
sudo ./svc.sh start

# macOS (launchd)
./svc.sh install
./svc.sh start
```

On macOS, the service runs as the installing user - matters for GUI access (iOS
simulator, Xcode) and for keychain unlock. Running `actions-runner` as a dedicated service
account that can't unlock the login keychain is a common iOS CI bug.

### Executor model

`actions-runner` is shell-only by default. It executes job steps directly on the host.
Container isolation is achieved at the **workflow** level via `jobs.<id>.container:` and
`jobs.<id>.services:`, which the runner orchestrates via Docker on the host. The runner
itself doesn't have "docker executor" as a separate install mode - it always runs on the
host and optionally spawns containers.

Implication: the **runner host itself is the trust boundary**. Attackers who compromise a
job can see everything the runner user can see. Ephemeral runners rebuilt from scratch
per job are the only real fix.

### Autoscaling: ARC

GitHub's recommended autoscaling pattern is **Actions Runner Controller (ARC)** on
Kubernetes. Upstream maintained at `actions/actions-runner-controller`. It creates a pod
per job, registers it as ephemeral, runs the job, and deletes the pod. Equivalent to
`gitlab-runner` with the kubernetes executor; different architecture.

Do not autoscale persistent runners - GitHub explicitly documents this as unsupported.

---

## `woodpecker-agent`

### Install

Woodpecker splits into `woodpecker-server` (one instance) and `woodpecker-agent` (many,
does the work).

Set `WOODPECKER_AGENT_IMAGE` to a reviewed version tag plus manifest digest from
the official registry before using the container install.

| Method | Command |
|--------|---------|
| Docker | `docker pull "${WOODPECKER_AGENT_IMAGE:?set to a reviewed tag@sha256 digest}"` |
| Docker Compose | Pair with the server compose file; reference in upstream docs |
| Binary | Download from GitHub releases, binary + env file |
| Kubernetes | Official Helm chart `woodpecker-ci/woodpecker` |

### Configure

Agents talk to the server over gRPC. Minimum env:

```bash
WOODPECKER_SERVER=woodpecker-server:9000
WOODPECKER_AGENT_SECRET=<shared secret from server config>
WOODPECKER_BACKEND=docker        # or kubernetes, local
WOODPECKER_MAX_WORKFLOWS=4        # concurrent workflow steps
```

### Backend choice

| Backend | Use case |
|---------|----------|
| `docker` | Default. Each step runs in a container. Same DinD/socket tradeoffs as other runners. |
| `kubernetes` | Each step becomes a Pod. Temporary PVC glues steps in one pipeline. Use when you have k8s. |
| `local` | Each step runs as a local process on the agent. No isolation; useful for testing the agent itself or highly trusted hosts. |

### Agent scaling

Idle agent ~30 MB RAM. Run many small agents (one per machine, or one per k8s node) rather
than one beefy agent with high concurrency - failure of one agent takes fewer jobs with it.

---

## Linux vs macOS Differences

### Package availability

| Runner | Linux packages | macOS install |
|--------|---------------|---------------|
| `gitlab-runner` | Official deb/rpm/AUR | `brew install gitlab-runner` |
| `forgejo-runner` | None - tarball or docker | tarball (`darwin-arm64`/`darwin-amd64`) |
| `gitea-runner` | None - tarball or docker | Tarball or via docker (Apple Silicon requires rosetta-free binary) |
| `actions-runner` | None - GitHub-hosted tarball | Same tarball flow |
| `woodpecker-agent` | None - docker is the norm | Docker via Colima/OrbStack or binary |

### Service management

| OS | Mechanism | Notes |
|----|-----------|-------|
| Linux | systemd unit (`gitlab-runner.service`, `forgejo-runner.service`, etc.) | Run as dedicated system user. `loginctl enable-linger` if using rootless Podman/Docker |
| macOS | launchd plist (`LaunchAgents` for user, `LaunchDaemons` for system) | User agents need an active login session to unlock keychain; system daemons can't access the login keychain |
| Windows | Windows Service via `nssm` or the runner's own installer | Same keychain/credential isolation issues as macOS |

### Containerization on macOS

Docker on macOS = Linux VM (Docker Desktop, Colima, OrbStack, Podman Machine). This breaks
two things:

1. **Native macOS builds** can't run in containers. iOS/macOS CI must use shell executors
   on real Macs. Ephemerality has to come from VM snapshots or reinstalled machines, not
   per-job containers.
2. **Resource overhead** is higher - every job step pays the Linux-VM tax. For pure Linux
   builds, a cheap Linux box is usually better than a Mac.

Rule: if the pipeline produces Linux artifacts, use a Linux runner. Macs are for macOS/iOS
artifacts only.

### File system quirks

- **macOS case-insensitive by default** - repos with files differing only in case break.
  Use APFS case-sensitive for CI volumes or add a CI check.
- **Linux containers on macOS file share** (Docker Desktop bind mounts) have notoriously
  slow I/O. For heavy CI, put caches on a tmpfs or dedicated volume, not a bind mount.

---

## Security Hardening

### Must-dos

1. **Never run self-hosted runners on public repos without ephemeral mode.** Anyone who
   can open a PR can run code on your runner. This is how runner-as-backdoor attacks start.
2. **Run the runner as a dedicated non-root user.** `gitlab-runner`, `forgejo-runner`,
   `gitea-runner` all create dedicated users in their systemd units; verify the user has no
   sudo and no access to other services' data.
3. **Drop docker socket access if jobs don't need to build images.** Mounting
   `/var/run/docker.sock` is equivalent to giving the job root on the host.
4. **Isolate runner network egress.** Runners should not reach internal services they
   don't need. Firewall outbound to registry + package repos + forge API only.
5. **Separate runners for trust levels.** Prod-deploying runners (with cloud credentials)
   should never run PR jobs from untrusted authors. Use separate runner groups, labels,
   or entire runner hosts.

### Should-dos

- **Ephemeral everywhere possible**: `gitlab-runner` + kubernetes/docker-autoscaler;
  `actions-runner` with `--ephemeral`; `gitea-runner --ephemeral`; `forgejo-runner` with
  a verified single-job exit wrapper plus fresh per-job host/container state; `woodpecker-agent` with k8s backend.
- **Rootless container runtime**: rootless Podman + rootless Buildkit for image builds.
  Eliminates privileged containers entirely.
- **Forward runner logs off-host**: log lines are evidence of compromise. On-host logs get
  wiped by attackers or by the ephemeral teardown.
- **Pin runner binary versions**. `--disableupdate` (GitHub), pinned apt versions
  (GitLab), pinned container tags (Forgejo/Gitea/Woodpecker). Auto-update is a supply
  chain vector.
- **Monitor for stuck runners**. Jobs that hang forever are a sign of DoS or compromise
  attempts.

### Public-repo safety

Never use non-ephemeral self-hosted runners on a public repo. The documented attack is
trivial: fork, open a PR with a malicious workflow change, the runner executes it with
persistent access to previous jobs' caches, credentials, and local state. If you must run
self-hosted on a public repo:

- GitHub: require approval before workflows run for outside contributors (Repo
  Settings -> Actions -> Approval required). Plus `--ephemeral`.
- GitLab: use protected variables + protected branches/tags. Shared runners tagged for
  untrusted jobs. Premium+ has "pre-approve MR pipelines".
- Forgejo/Gitea: Actions default to not running on PRs from forks unless enabled. Keep it
  that way.
- Woodpecker: similar default.

---

## Common Failure Modes

**"Runner is offline but process is running"**: token rotation, network ACL change, or
clock skew. Check the runner log - the handshake error names the cause.

**"Job waits forever, never starts"**: runner tag/label mismatch. On GitLab, `tags:
[linux]` requires a runner registered with the exact tag `linux`. On Forgejo/Gitea,
`runs-on: ubuntu-latest` needs the runner to declare `ubuntu-latest:docker://...`.

**"Docker: permission denied /var/run/docker.sock"**: the runner user isn't in the
`docker` group. `usermod -aG docker <runner-user>`, then restart the runner.

**"Working directory already exists, clean failed"**: shell executor state leak from a
previous job. Stop using shell for shared runners or wipe the workdir on each run. This is
the leak that makes shell runners unsafe.

**"Out of disk space" mid-build**: Docker image layers accumulate on long-lived runners.
Inspect usage and retention first; prune only approved unused resources on an isolated
runner with no active jobs. Prefer disposable runners; do not schedule broad volume deletion blindly.

**macOS keychain unlock prompt blocks job**: runner is running as a user without an active
login session. For iOS builds, run the runner as the logged-in user with `security
unlock-keychain` at the start of each job (and do not commit the keychain password).

**Runner pulls cold on every job**: no image pull cache. Use a registry mirror or reviewed prewarming. Do not use `if-not-present` on shared
multitenant runners where cached private images could be reused without authorization.
Pull behavior follows the runner policy, not a universal `latest` rule.

**DinD races on parallel jobs**: two jobs on the same runner both starting a DinD sidecar
fight over port 2376 (TLS, default since Docker 20+) or 2375 (no TLS). Lower concurrency
on DinD runners or use kubernetes backend which gives each job its own network namespace.

---

## Cross-References

- GitHub Actions security patterns: `references/github-actions.md`
- GitLab CI/CD (tags, compute minutes, SaaS vs self-managed): `references/gitlab-ci.md`
- Forgejo/Gitea Actions and Woodpecker pipeline patterns: `references/forgejo-gitea-actions.md`
- Supply chain / SHA pinning for runner images: `references/supply-chain.md`
