# Forgejo Actions Troubleshooting

Use this when a Forgejo Actions run fails but the failure is only visible as a notification or task status, especially for scheduled Docker image builds.

## Fast triage

1. Identify the failed task and adjacent successful runs:

```bash
fj actions tasks -p 1
```

Compare task id, commit, event, duration, and workflow/job name. If the same workflow and same commit succeeded immediately before or after, suspect runner, network, registry, cache, or external service flake before editing code.

2. Inspect the workflow file and reproduce the exact shell-visible parts locally:

```bash
sed -n '1,220p' .forgejo/workflows/<workflow>.yaml
```

For Docker build workflows, run the same build context, Dockerfile, tags, scanner image, scanner flags, and ignore file locally.

3. Keep private registry state explicit. A remote image manifest probe may fail with `unauthorized` unless this machine is logged in to the registry, even if the CI runner has a working token. Treat that as an auth-state finding, not proof that the image is absent.

## Docker build workflow reproduction pattern

```bash
docker build --pull -t local-debug:<name> <context>

docker tag local-debug:<name> <registry>/<owner>/<image>:<tag>

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD/<path>/.trivyignore:/work/.trivyignore:ro" \
  -w /work \
  aquasec/trivy:<version> image \
  --severity CRITICAL,HIGH \
  --ignore-unfixed \
  --ignorefile /work/.trivyignore \
  --exit-code 1 \
  --format table \
  <registry>/<owner>/<image>:<tag>
```

Adjust scanner flags to match the workflow exactly. If local build and scan pass, do not claim the workflow is fixed. Report the narrowed failure domain and suggest rerun only if authorized.

## Forgejo API and logs caveat

Some Forgejo versions expose Actions task listings through the CLI but do not expose job logs through token-friendly API endpoints, or return `403` for unauthenticated/session-only endpoints. When logs are unavailable:

- use `fj actions tasks` for task metadata
- use adjacent successful runs for comparison
- reproduce deterministic steps locally
- avoid guessing the exact failing step

## Pitfalls

- `permissions:` in Forgejo workflow YAML is parsed for compatibility but is not a reliable least-privilege boundary like GitHub Actions.
- Scheduled Docker builds can fail from registry/buildcache/network flakes while code remains valid.
- `docker manifest inspect <private-registry-image>` can fail locally with `unauthorized`; check local Docker login state before drawing conclusions.
- Do not rerun, push, or merge from a bot notification unless the authorized human explicitly asked for that action.
