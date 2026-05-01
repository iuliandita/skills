# Public Custom Container Image Publishing

Use this when a private infra repo builds a custom image and the user asks whether
an equivalent public image exists or whether to publish one.

## Discovery Workflow

1. Identify the exact module/build delta, not just the base app name.
   - A common plugin or extension alone may already have public images.
   - A particular combination of plugins, entrypoint behavior, and tags may be a
     distinct operational contract.
2. Search public registries and source repos separately:
   - Docker Hub, GHCR, and other registries for pullable images and freshness.
   - Source search for exact module strings in Dockerfiles or build scripts.
   - Upstream docs for whether modules are official, community, or unsupported.
3. Distinguish "same broad category" from "same operational contract".
   - Module set, tags, base image family, multi-arch support, update cadence,
     entrypoint behavior, and registry freshness all matter.
4. Inspect the local repo CI before recommending migration.
   - Existing schedule/manual triggers.
   - Registry targets.
   - scan/sign/SBOM behavior.
   - whether the current repo is private or contains unrelated infra, secrets,
     or private history.

## Recommendation Pattern

For private infra repos, do not recommend making the whole repo public or moving
it wholesale unless the user explicitly wants that. Prefer a tiny public image
repo containing only:

```text
Dockerfile
entrypoint.sh
.dockerignore
.trivyignore
README.md
LICENSE
.github/workflows/build.yml
```

The private repo can keep its internal build or switch to the public image after
several green public builds.

## Public Registry Checklist

- Push to GHCR with GitHub Actions `GITHUB_TOKEN` when possible; it links the
  package to the repo automatically.
- Push to Docker Hub with `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets.
- Add OCI labels, especially:
  - `org.opencontainers.image.source`
  - `org.opencontainers.image.description`
  - `org.opencontainers.image.licenses`
  - `org.opencontainers.image.version`
- Build with `docker/build-push-action` using `push: true`, not `load: true`
  plus manual pushes, when publishing multi-registry images.
- Enable `sbom: true` and `provenance: true` where supported.
- Prefer upstream-compatible tag aliases over only `latest`. For images that
  track a versioned upstream base, mirror the upstream tag layout for the pinned
  version when it is safe to do so.
- Generate major and minor tag aliases from a single app version variable in CI
  instead of hand-maintaining aliases.
- Verify every tag on every registry with `docker manifest inspect`.
- Consider multi-arch at least `linux/amd64,linux/arm64` for public images, but
  do not blindly enable QEMU for compile-heavy images. Prefer native ARM runners
  or a split-arch manifest workflow; otherwise publish `linux/amd64` first and
  add ARM after the first public image is green.
- If publishing `linux/amd64` only, do not include `docker/setup-qemu-action`;
  it adds noise and is only needed for emulated cross-arch builds.
- For GitHub public repos, native ARM is available with `runs-on: ubuntu-24.04-arm`.
  A reliable pattern is:
  1. build `linux/amd64` on `ubuntu-24.04` and tag each result as `<tag>-amd64`;
  2. build `linux/arm64` on `ubuntu-24.04-arm` and tag each result as `<tag>-arm64`;
  3. merge public tags with `docker buildx imagetools create`.
- If `sbom: true` or `provenance: true` is enabled, manifest lists may also include
  `unknown/unknown` attestation entries. Do not treat those as broken platforms.
- Document any root entrypoint or permission-fixing behavior clearly. A root
  entrypoint that chowns volumes then drops privileges can be useful, but it is
  a public-image security expectation that must be explicit.
