# Contributing

Open an issue before starting a bug fix or a substantial change, and reference it in the PR
(`Closes #NN` for a completed fix). Branch from `develop`, keep changes small, and preserve
unrelated local settings. Report suspected vulnerabilities through [SECURITY.md](SECURITY.md),
not a public issue.

## Sources and generated files

Each installed skill must be self-contained. Edit `skills/<name>/SKILL.md` and its references.
`skills/_shared/output-contract.md` and `skills/_shared/agent-hygiene.md` are build-time
sources: run `scripts/gen-contract-refs.sh` after changing either, rather than editing
generated copies.
Regenerate long reference contents lists with `python3 scripts/gen-ref-toc.py`.
Keep protected overlays and private markers out of commits.

## Checks and documentation

```sh
./scripts/lint-skills.sh
./scripts/validate-spec.sh
for f in scripts/check-*.sh; do "$f"; done
```

Mirror the checks in `.github/workflows/lint.yml`.
Freshness labels and receipt age remain advisory. Installer changes also need the existing
installer tests; use [skill authoring](docs/skill-authoring.md) for content checks.
[INSTALL.md](INSTALL.md) documents installation, update, backups and recovery;
[MIGRATION.md](MIGRATION.md) documents renamed/removed skills.
The existing docs-impact check covers skill removals/renames, tool-path changes, installer
changes and added/removed gate scripts; it does not establish prose correctness or cover
every file. Explain any documented no-impact exclusion in the PR.
`install.sh --check` compares source with recorded install hashes, not runtime activation or
all local destination edits. Smoke-test important behavior in the consuming harness.

## Releases

Feature and fix PRs target `develop` and are squash-merged. The version bump follows the
conventional-commit titles since the last tag: `feat` is minor, `fix` and `deps` are patch, `!` or
`BREAKING CHANGE:` is major; `docs`, `chore`, `ci`, `test`, `style` alone do not release.

1. On `develop`, bump the version and move the `Unreleased` changelog entries under the new
   version, by PR.
2. Open a PR from `develop` to `main` and merge it with a merge commit, never a squash, so `main`
   stays an ancestor of `develop`.
3. Tag the merge on `main` as `v<version>` and push the tag. The release workflow checks the tag
   and publishes the notes from the changelog.

The full procedure, including the documentation-impact gate, is in [INSTALL.md](INSTALL.md#releases).
