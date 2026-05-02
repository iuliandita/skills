# Supply Chain Incident Triage Notes

Use this when a public package compromise lands and the user asks whether their repos are affected. Keep it repo-only unless the user asks for live infra or token rotation work.

## Pattern: compromised package exposure check

1. Verify the incident from primary sources first: upstream security advisory, package registry quarantine/yank notice, and 1-2 reputable security writeups for IOCs.
2. Extract exact affected package names, versions, execution trigger, and remediation:
   - import-time compromise means search dependencies and source imports
   - install-time compromise means search locks/manifests and package lifecycle hooks
3. Search all repo manifests and lockfiles, not only source imports:
   - Python: `pyproject.toml`, `requirements*.txt`, `setup.py`, `setup.cfg`, `poetry.lock`, `uv.lock`, `Pipfile.lock`, conda env files
   - Node: `package.json`, `package-lock.json`, `npm-shrinkwrap.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`
4. Search source for runtime imports/usages that may pull dynamic dependencies:
   - `import <package>`, `from <package>`, framework-specific import aliases
5. Search for campaign IOCs separately from package names:
   - payload files/directories
   - injected lifecycle hooks
   - suspicious branch names
   - unusual commit authors/emails
   - newly created mass branches after disclosure time
6. Check local runtime environments only if relevant and low-risk, using non-importing checks first:
   - `python3 -m pip show <pkg>`
   - `python3 - <<'PY'` with `importlib.util.find_spec()` instead of importing the suspect package
7. If GitHub propagation is part of the campaign, check remote repos updated since the incident:
   - branch counts and suspicious branch names
   - recent commits by known malicious author/email or with IOC strings
   - avoid destructive cleanup unless explicitly authorized
8. Report in three buckets:
   - direct vulnerable dependency found
   - indicators of compromise found
   - clean/no evidence found, with scope and caveats

## April 2026 Mini Shai-Hulud example

Public reporting around the April 2026 campaign described these affected versions. Treat this as an example and verify current advisories before acting:

- PyPI `lightning==2.6.2` and `lightning==2.6.3`
- npm `intercom-client@7.0.4`
- clean pins reported by public writeups: `lightning==2.6.1`, `intercom-client@7.0.3`

Execution triggers:

- `lightning`: import-time execution
- `intercom-client`: install-time npm lifecycle hook

Useful IOCs/patterns reported publicly:

- `_runtime/`
- `router_runtime.js`
- suspicious package lifecycle `postinstall` changes
- GitHub propagation using stolen tokens, including many branches per writable repo in some reports
- commits reported with author email `claude@users.noreply.github.com`

If any direct hit exists, advise treating that environment as compromised: rotate secrets, rebuild from clean state, review logs, and pin to known clean versions. If only unrelated string matches appear, call them out explicitly as false positives, e.g. `lightningcss` is not PyTorch Lightning.
