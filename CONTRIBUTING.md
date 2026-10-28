# Contributing

Open an issue before starting a bug fix or a substantial change, and reference it in the PR
(`Closes #NN` for a completed fix). Keep changes small and preserve unrelated local settings.
Report suspected vulnerabilities through [SECURITY.md](SECURITY.md), not a public issue.

## Sources and generated files

Each installed skill must be self-contained. Edit `skills/<name>/SKILL.md` and its references.
`skills/_shared/output-contract.md` and `skills/_shared/agent-hygiene.md` are build-time
sources: run `scripts/gen-contract-refs.sh` after changing either, rather than editing
generated copies.
Regenerate long reference contents lists with `python3 scripts/gen-ref-toc.py`.
Keep protected overlays and private markers out of commits.

## Checks and documentation

Run `scripts/lint-skills.sh`, `scripts/validate-spec.sh`, and the collection's
`scripts/check-*.sh` gates; mirror the checks in `.github/workflows/lint.yml`.
Freshness labels and receipt age remain advisory. Installer changes also need the existing
installer tests; use [skill authoring](docs/skill-authoring.md) for content checks.
[INSTALL.md](INSTALL.md) documents installation, update, backups and recovery;
[MIGRATION.md](MIGRATION.md) documents renamed/removed skills.
The existing docs-impact check covers skill removals/renames, tool-path changes, installer
changes and added/removed gate scripts; it does not establish prose correctness or cover
every file. Explain any documented no-impact exclusion in the PR.
`install.sh --check` compares source with recorded install hashes, not runtime activation or
all local destination edits. Smoke-test important behavior in the consuming harness.
