# skills

Agent Skills, installed one at a time with `npx skills add` or `install.sh`, so every skill must be
self-contained. `develop` is the default and nightly branch, `main` is stable.

If `AGENTS.local.md` exists beside this file, read it too. It holds local paths and preferences and never
relaxes the rules here.

## Commands

Pre-push set mirroring `.github/workflows/ci.yml` and `security.yml`. Tools: shellcheck,
markdownlint-cli2 (pinned in `.github/tools/markdownlint/`), lychee, actionlint, gitleaks, semgrep.

```sh
./scripts/lint-skills.sh
./scripts/validate-spec.sh
for f in scripts/check-*.sh; do "$f" || echo "FAIL $f"; done
python3 .github/stack/stack-check.py
for f in scripts/test-*.sh; do "$f" || echo "FAIL $f"; done
python3 scripts/test-migrations.py
shellcheck install.sh scripts/*.sh skills/repo-audit/references/detect.sh
markdownlint-cli2
lychee --config lychee.toml README.md SECURITY.md CONTRIBUTING.md CHANGELOG.md INSTALL.md MIGRATION.md AGENTS.md skills docs
actionlint
gitleaks git --redact .
semgrep scan --metrics off --error --config p/ci --config p/github-actions install.sh scripts .github/workflows skills/repo-audit/references/detect.sh
./scripts/gen-contract-refs.sh
python3 scripts/gen-ref-toc.py
```

The last two regenerate files; commit their output. `check-freshness-dates.sh` and receipt age are
advisory. `pre-commit install --hook-type pre-commit --hook-type pre-push` wires the local hooks.

## Layout

- `skills/<name>/`: one installable skill. Never reference paths outside it at runtime.
- `skills/_shared/`: build-time sources only. Each skill's `references/output-contract.md` and
  `agent-hygiene.md` are generated from them; never hand-edit those copies.
- `scripts/`: gates (`check-*.sh`, `lint-skills.sh`, `validate-spec.sh`) and their tests (`test-*`).
- `.refiner-runs.json`, `.refiner-ledger.md`: skill-refiner history at the root by contract; append only.
- `.github/stack/`: vendored from agents; do not edit.
- Details: [CONTRIBUTING.md](CONTRIBUTING.md), [INSTALL.md](INSTALL.md), [MIGRATION.md](MIGRATION.md).

## Rules

- Issue first, branch from `develop`, PR into `develop`, conventional commits, `Closes #NN`. Never commit to `main` or `develop`.
- No AI attribution in commits, PRs, tags, or files.
- No private hosts, domains, IPs, machine paths, or work context in tracked files.
- `SKILL.md` stays at 500 lines or fewer; every reference is linked from it.
- A new active skill needs repo-audit coverage (see CONTRIBUTING.md); renames and removals need
  a `migrations.json` entry and a `MIGRATION.md` change.
- Keep protected overlays and private markers out of commits.

## For agents

- `./install.sh --json` (installs, `--list`, `--check`, `--detect`, `--doctor`, `--migrate`,
  `--update`) prints one JSON object; keys and exit codes are in [INSTALL.md](INSTALL.md#json-output).
- There is no single all-checks command; the block above is the full set and CI is the source of truth.
