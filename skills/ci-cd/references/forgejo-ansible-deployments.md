# Forgejo Actions for Ansible Infra Deployments

Use this when a Forgejo or Gitea Actions workflow deploys Ansible playbooks based
on changed paths.

## Pattern

For infra repos that fan out Ansible deploy jobs by changed path:

1. Inspect the workflow under `.forgejo/workflows/` or `.gitea/workflows/`
   before assuming `site.yml` runs on every push.
2. Check whether a detect-changes job emits booleans for specific roles,
   playbooks, or inventory areas.
3. When adding a shared role or baseline playbook, add all required pieces:
   - workflow `on.push.paths` entry if path filtering is used
   - a detect-change output, such as `baseline: ${{ steps.changes.outputs.baseline }}`
   - a deploy job that actually runs the new playbook
4. For a baseline playbook spanning multiple host groups, provision every SSH
   key required by inventory, not just the service-specific key.
5. Add a manual `workflow_dispatch` input for one-shot reruns.
6. After pushing, verify with the forge's Actions task view or CLI, not just
   local YAML syntax.

## Example Baseline Job Shape

```yaml
deploy-baseline:
  needs: detect-changes
  if: needs.detect-changes.outputs.baseline == 'true' || github.event_name == 'workflow_dispatch'
  runs-on: self-hosted
  steps:
    - uses: actions/checkout@<pinned-sha> # vX
    - name: Set up SSH and vault
      env:
        SSH_KEY_PRIMARY: ${{ secrets.SSH_KEY_PRIMARY }}
        SSH_KEY_SECONDARY: ${{ secrets.SSH_KEY_SECONDARY }}
        ANSIBLE_VAULT_PASSWORD: ${{ secrets.ANSIBLE_VAULT_PASSWORD }}
      run: |
        mkdir -p ~/.ssh
        echo "$SSH_KEY_PRIMARY" > ~/.ssh/id_primary
        chmod 600 ~/.ssh/id_primary
        echo "$SSH_KEY_SECONDARY" > ~/.ssh/id_secondary
        chmod 600 ~/.ssh/id_secondary
        echo "$ANSIBLE_VAULT_PASSWORD" > /tmp/.vault_pass
        chmod 600 /tmp/.vault_pass
    - name: Deploy baseline
      run: |
        cd ansible
        ANSIBLE_VAULT_PASSWORD_FILE=/tmp/.vault_pass ansible-playbook playbooks/baseline.yml
    - name: Cleanup secrets
      if: always()
      run: rm -f /tmp/.vault_pass ~/.ssh/id_primary ~/.ssh/id_secondary
```

## Validation

```bash
python3 - <<'PY'
from pathlib import Path
import yaml
yaml.safe_load(Path('.forgejo/workflows/deploy.yml').read_text())
print('yaml-ok')
PY

(cd ansible && ansible-playbook playbooks/baseline.yml --syntax-check)
git diff --check
```

A successful push should show the detect-changes job and the expected deploy job
as successful, with unrelated fan-out jobs skipped.

## Pitfalls

- Adding only an Ansible playbook is not enough if CI uses per-role fan-out.
- A broad `on.push.paths: ansible/**` can trigger the workflow while every
  deploy job skips if no detect-change output matches the new role.
- `site.yml` may include the new role but not actually be executed in CI; verify
  the job command.
- Include the workflow file itself in `on.push.paths` if workflow edits should
  trigger a verification deploy.
- Keep secrets in `env:` and write them to files with mode `0600`; clean them
  up in an `always()` step.
