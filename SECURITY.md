# Security Policy

## Supported Versions

Security fixes target `develop` and reach users through `main` and the next tagged release. The only long-lived branches are `develop` and `main`, so fixes are not backported to older releases.

## Reporting a Vulnerability

Please do not open a public issue for suspected security problems.

Use one of these channels instead:

- [GitHub Security Advisories for this repository](https://github.com/iuliandita/skills/security/advisories/new)

Include:

- a clear description of the issue
- affected files, versions, or commits
- reproduction steps or a proof of concept
- impact assessment

I will acknowledge receipt as soon as practical, investigate, and work on a fix before public disclosure.

## Update Trust Model

`install.sh --update` fetches the branch recorded by `install.sh --save` and runs the
`install.sh` from the fetched commit as your user. By default it runs whatever lands on that
branch: nothing checks who made the commit, so scheduling `--update` trusts the remote, every
account that can push to the branch, and the transport.

`install.sh --save --verify-signature` adds one check, stored in the saved config: `--update`
runs `git verify-commit` on the fetched commit before it moves the checkout, and refuses
(exit 9, checkout unchanged, fetched installer not run) unless it passes. Passing proves the
commit carries a good signature from a key in your own keyring, whatever trust level that key
has. For this repository's GitHub merges that key is GitHub's web-flow key, so a pass means
"merged through GitHub", not "signed by the maintainer". Details and limits are in
[INSTALL.md](INSTALL.md#signature-verification).

## Scope

- `install.sh` and its helpers in `scripts/`: writing outside the selected skill directories,
  unsafe symlink or path handling, lost backups, or overwriting edited installed copies
  without the documented protection.
- Skill content in `skills/` that tells an agent to expose secrets, skip the confirmation a
  skill promises for consequential steps, or run unsafe commands by default.
- Leaks of private overlays or private markers into published files, and gaps in the checks
  meant to stop them.
- This repository's GitHub Actions workflows and pinned CI tools.

## Not in Scope

- How a coding agent, harness, or model activates, loads, or follows a skill. Skills are
  instructions the agent runs with your permissions; runtime behavior depends on the consuming
  tool.
- Third-party installers such as `npx skills`, and the tools, services, and credentials a skill
  describes but does not ship.
- Private overlays and other local edits you add to installed skills.
- Using offensive-security skills against systems you are not authorized to test.

## Disclosure Expectations

Please give me reasonable time to validate the report and ship a fix before sharing details publicly.

Once a fix is available, I may publish a summary so users know they should update.
