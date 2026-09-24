# Changelog

All notable changes to this project will be documented in this file.

## [2.2.1](https://github.com/iuliandita/skills/compare/v2.2.0...v2.2.1) (2026-09-24)

### Bug Fixes

* **install:** report up-to-date skills as `[=] <skill> current` instead of asking for `--force`; copies that differ or cannot be verified are reported as such and never published to the lock file ([#230](https://github.com/iuliandita/skills/pull/230), [#229](https://github.com/iuliandita/skills/issues/229)).
* **migrate:** write the migration lock and replacement skills atomically, retire legacy entries by rename, and let a rerun finish any interrupted migration. `install.sh --migrate --apply` now requires `flock` and holds the installer lock through recovery ([#231](https://github.com/iuliandita/skills/pull/231), [#224](https://github.com/iuliandita/skills/issues/224)).

## [2.2.0](https://github.com/iuliandita/skills/compare/v2.1.1...v2.2.0) (2026-09-24)

### Features

* **install:** add `--detect`, which lists harness candidates from binaries on PATH and harness-owned config files without running anything, and `--save`, which stores the install selection and the checkout's source identity for later runs ([#226](https://github.com/iuliandita/skills/pull/226), [#204](https://github.com/iuliandita/skills/issues/204)).
* **install:** add a cron-safe `--update` that fast-forwards the saved source to a pinned commit, hands off to the updated installer under the same lock, and replaces only skills whose content changed; local edits are kept and reported, and every outcome has a documented exit code ([#227](https://github.com/iuliandita/skills/pull/227), [#204](https://github.com/iuliandita/skills/issues/204)).

### Bug Fixes

* **install:** stage, record, and roll back skill replacements under a shared lock when `flock` is available, recover interrupted runs, write the lock file and OpenCode config atomically, and exit non-zero whenever a step fails ([#225](https://github.com/iuliandita/skills/pull/225), [#223](https://github.com/iuliandita/skills/issues/223)).
* **install:** make `--doctor` lead with blocking findings and collapse overlaps the harness resolves itself into counts, with `--verbose` for the full list ([#222](https://github.com/iuliandita/skills/pull/222), [#221](https://github.com/iuliandita/skills/issues/221)).

## [2.1.1](https://github.com/iuliandita/skills/compare/v2.1.0...v2.1.1) (2026-09-24)

### Bug Fixes

* **install:** install codex, commandcode, and opencode once into `~/.agents/skills`, which they already read, instead of a second copy that harnesses reported as duplicates. `--migrate` previews and `--migrate --apply` removes the old links after a backup, only when the lock records them and a verified replacement exists. New read-only `--doctor` reports skill names a harness can reach through more than one directory ([#215](https://github.com/iuliandita/skills/pull/215), [#212](https://github.com/iuliandita/skills/issues/212)).
* **ci:** stop the whitespace check from shallowing full clones, which made the refiner phase-1 guard flag old commits once main moved; the guard now fails loudly when it cannot compute a merge base ([#214](https://github.com/iuliandita/skills/pull/214), [#211](https://github.com/iuliandita/skills/issues/211)).
* **scripts:** keep fixture tests from acting on the caller's repository when git exports `GIT_DIR` ([#219](https://github.com/iuliandita/skills/pull/219), [#218](https://github.com/iuliandita/skills/issues/218)).

### Performance Improvements

* **install, lint:** parse skill frontmatter once per run and skip per-line forks in lint; a docs-only pre-push went from about 6 minutes to 25 seconds, and the installer tests run on pre-push only when installer files change ([#217](https://github.com/iuliandita/skills/pull/217), [#209](https://github.com/iuliandita/skills/issues/209), [#216](https://github.com/iuliandita/skills/issues/216)).

## [2.1.0](https://github.com/iuliandita/skills/compare/v2.0.1...v2.1.0) (2026-09-24)

### Features

* **install:** add the `omp` (Oh My Pi) target, installed to `~/.agents/skills` with an installer-only `OMP_SKILLS_DIR` override, and mark `gemini` as a legacy target ([#207](https://github.com/iuliandita/skills/pull/207), [#200](https://github.com/iuliandita/skills/issues/200)).
* **scripts:** accept user-supplied private leak markers from a gitignored `private-patterns.txt` or `SKILLS_PRIVATE_PATTERNS`, and fail on scanner errors ([#210](https://github.com/iuliandita/skills/pull/210), [#202](https://github.com/iuliandita/skills/issues/202)).

### Bug Fixes

* **llm-app-development:** refresh model facts for Opus 5.5, Sonnet 5, GPT-6 Sol/Luna, and DeepSeek V4.1 Flash; fix examples for thinking-on-by-default responses, sampling-parameter rejections, and incomplete stops ([#205](https://github.com/iuliandita/skills/pull/205), [#198](https://github.com/iuliandita/skills/issues/198)).
* **skill-refiner:** refresh harness detection for Antigravity, Command Code, Oh My Pi, Hermes, and OpenCode, with updated headless forms, recorded probe results, and exact process-name matching ([#206](https://github.com/iuliandita/skills/pull/206), [#199](https://github.com/iuliandita/skills/issues/199)).
* **dev-cycle:** pass explicit conventional squash subjects and bodies per forge, and allow start through finish in one session on explicit request ([#208](https://github.com/iuliandita/skills/pull/208), [#201](https://github.com/iuliandita/skills/issues/201)).

## [2.0.1](https://github.com/iuliandita/skills/compare/v2.0.0...v2.0.1) (2026-09-20)

### Bug Fixes

* **skills:** resolve the 36 confirmed v2 audit findings: preserve target identity and diagnostic errors, verify TLS and recipient keys, protect deployment authorization and credentials, and require evidence before claiming security impact ([#196](https://github.com/iuliandita/skills/pull/196), [#195](https://github.com/iuliandita/skills/issues/195)).
* **skills:** correct platform recipes and active routing; align workload probes, package operations, backup policy, locale loading, and workflow deliverables ([#196](https://github.com/iuliandita/skills/pull/196)).
* **skill-refiner:** correct the active Kali routing test, require complete-read provenance and valid per-case grades, clarify review checkpoints, and record the v2 collection sweep ([#196](https://github.com/iuliandita/skills/pull/196)).

## [2.0.0](https://github.com/iuliandita/skills/compare/v1.46.0...v2.0.0) (2026-09-20)

### Breaking Changes

* Replace 19 old skill names with temporary migration notices. Merge review pairs into `code-simplification`, `repo-audit`, and `plan-review`; rename ten skills; retire `browse`, `routine-writer`, and `skill-router`. The notices no longer provide the former workflows. See [the complete mapping and migration instructions](MIGRATION.md).
* Keep notices for one transition release and at least seven full days after actual publication. Existing copied installations require an update or explicit migration; upstream changes do not automatically remove them.

### Features

* Publish 43 active skills with clearer names, task-focused descriptions, preserved specialist references, and shorter reporting instructions ([#191](https://github.com/iuliandita/skills/pull/191)).
* Add `message-queues` and `performance-debugging`; expand Redis/Valkey, GraphQL/gRPC, secrets lifecycle, restore drills, and accessibility coverage ([#191](https://github.com/iuliandita/skills/pull/191)).
* Add preview-first migration with backups and conservative ownership checks for bundled installs. Keep modified, protected, and ambiguous entries for manual migration ([#191](https://github.com/iuliandita/skills/pull/191)).

### Bug Fixes

* Separate deprecated notices from active skill routing and refinement scores while preserving migration tests; correct merged-mode behavioral expectations and honor repository retirement policies ([#192](https://github.com/iuliandita/skills/issues/192)).
* Harden migration hashing, moved-checkout updates, shared link preservation, backup destinations, and replacement permission synchronization ([#191](https://github.com/iuliandita/skills/pull/191)).


## [1.46.0](https://github.com/iuliandita/skills/compare/v1.45.8...v1.46.0) (2026-09-17)

### Features

* **install:** support the Command Code target (`~/.commandcode/skills`) and the `agy` alias for Antigravity, add the `command-code` and `cmdc` aliases, and fix the Antigravity skills path to `~/.gemini/config/skills` based on the `agy` CLI's documented global discovery ([#188](https://github.com/iuliandita/skills/pull/188)).

## [1.45.8](https://github.com/iuliandita/skills/compare/v1.45.7...v1.45.8) (2026-09-17)

### Bug Fixes

* **skills:** correct defects across the collection found by a skill-refiner run under the new penalty-only scoring model - Gitea/Forgejo `tea` CI-watch commands, an OpenAI fine-tuning CLI example, an akmods probe flag that mutated state, a BinDiff/Ghidra claim, a subscription connection pointer, credential hygiene in examples, reciprocal routing boundaries, and CIDR/DNS tables moved out of always-loaded context ([#186](https://github.com/iuliandita/skills/pull/186)).
* **skill-creator, skill-refiner, skill-router:** fix meta-skill defects found in review - the plateau boundary against the 2-point noise floor, the structural-gate re-score wording, a self-contradictory audit example, and the `allowed-tools` separator ([#186](https://github.com/iuliandita/skills/pull/186)).
* **dev-cycle:** tolerate suffixless remotes in the Gitea run-lister and record the 2026-09-17 skill-refiner run in the ledger ([#186](https://github.com/iuliandita/skills/pull/186)).

## [1.45.7](https://github.com/iuliandita/skills/compare/v1.45.6...v1.45.7) (2026-09-17)

### Bug Fixes

* **skills:** correct reference defects across the collection - Forgejo/Gitea CLI routing, Uvicorn shutdown default, snapshot review rule, Java virtual-thread flag, Terraform and Checkov examples, nginx advisories, Kubernetes minors, CI Trivy pins, Docker image pins, and reciprocal routing boundaries ([#170](https://github.com/iuliandita/skills/pull/170), [#171](https://github.com/iuliandita/skills/pull/171)).
* **skills:** relax overrestrictive defaults - skill-refiner meta-improvement is opt-in for a single-skill run, Rules sections hold only genuine constraints, and prompt frontmatter applies only to saved files ([#172](https://github.com/iuliandita/skills/pull/172)).
* **skill-refiner:** make the composite a penalty-only, versioned measurement and enforce the gate from outside the run ([#178](https://github.com/iuliandita/skills/pull/178), [#179](https://github.com/iuliandita/skills/pull/179)).
* **skill-refiner:** make peer review independent and attested, freeze the test oracle, and treat candidate content as data ([#180](https://github.com/iuliandita/skills/pull/180), [#181](https://github.com/iuliandita/skills/pull/181)).
* **skill-refiner:** portability, focus-mode regression sweep, run-history retention, and a zero-skill validation guard ([#182](https://github.com/iuliandita/skills/pull/182), [#184](https://github.com/iuliandita/skills/pull/184)).

## [1.45.6](https://github.com/iuliandita/skills/compare/v1.45.5...v1.45.6) (2026-09-10)

### Bug Fixes

* **skills:** correct reference inaccuracies and behavioral gaps found by a third fresh-context refinement pass - Helm nil-value and QoS guidance, Terraform cross-variable validation and Checkov policy IDs, LVM thin-pool and Proxmox disk-resize semantics, ansible Galaxy token handling, NixOS systemd-initrd impermanence, and the deep-audit wave-3 list ([#153](https://github.com/iuliandita/skills/pull/153)).
* **skill-creator, skill-refiner:** complete the deferred meta-improvement - correct LVM interpretation, scope reserved words to the platform, realistic routing-overlap and audience-led compliance, qualitative effort tiers, a hardened harness probe, and reconciled requested-round and simplicity rules ([#153](https://github.com/iuliandita/skills/pull/153)).

## [1.45.5](https://github.com/iuliandita/skills/compare/v1.45.4...v1.45.5) (2026-09-10)

### Bug Fixes

* **skills:** shorten descriptions, scope verification to the change, refresh September references, and correct shell, API, backup, infrastructure, prose, and audit guidance ([#151](https://github.com/iuliandita/skills/pull/151)).
* **skill-refiner:** record two collection refinement rounds and retain remaining deductions; iteration 3 and meta-skill changes are deferred in [#150](https://github.com/iuliandita/skills/issues/150).

## [1.45.4](https://github.com/iuliandita/skills/compare/v1.45.3...v1.45.4) (2026-09-09)

### Bug Fixes

* **frontend-design:** ground visual direction in the brief, preserve brand choices, keep concise opinionated critiques, and correct theme and gesture examples ([#138](https://github.com/iuliandita/skills/pull/138)).

## [1.45.3](https://github.com/iuliandita/skills/compare/v1.45.2...v1.45.3) (2026-09-08)

### Bug Fixes

* **skills:** honor authorized local edits, keep reviews read-only, and scale reporting and verification to the task ([#132](https://github.com/iuliandita/skills/issues/132)).
* **ai-ml:** document model migration constraints and provide a Responses API example.
* **skill-refiner:** verify reviewer model identity, apply review deductions before keeping changes, and expand behavioral coverage.

## [1.45.2](https://github.com/iuliandita/skills/compare/v1.45.1...v1.45.2) (2026-09-04)


### Bug Fixes

* **skills:** refresh September guidance and quality gates ([#131](https://github.com/iuliandita/skills/issues/131)) ([ccfce41](https://github.com/iuliandita/skills/commit/ccfce41274122bd06f27708bf73bdb89ecb44dd0))

## [1.45.1](https://github.com/iuliandita/skills/compare/v1.45.0...v1.45.1) (2026-08-19)


### Bug Fixes

* **skill-refiner:** consolidate split run history, harden CI ([#127](https://github.com/iuliandita/skills/issues/127)) ([aae1ce6](https://github.com/iuliandita/skills/commit/aae1ce6335d11829bc696043e9e28a6484057791))

## [1.45.0](https://github.com/iuliandita/skills/compare/v1.44.0...v1.45.0) (2026-08-19)


### Features

* **anti-ai-prose:** add inline mode and fold in unslop rules ([#126](https://github.com/iuliandita/skills/issues/126)) ([d3b3be3](https://github.com/iuliandita/skills/commit/d3b3be36fe64f594beb186495ab671f1cdf5c7f0))

## [1.44.0](https://github.com/iuliandita/skills/compare/v1.43.0...v1.44.0) (2026-07-29)


### Features

* **freshness:** verify version pins by receipt age, not month label ([#119](https://github.com/iuliandita/skills/issues/119)) ([f49c1da](https://github.com/iuliandita/skills/commit/f49c1daf29aa4eaff4d9f91902a2a855e939610b))
* **skills:** add shared agent-hygiene reference ([#120](https://github.com/iuliandita/skills/issues/120)) ([11b64f0](https://github.com/iuliandita/skills/commit/11b64f07dca140feb583331ac63721bdfdeb16fe))
* **lint:** cap generic self-check ratio ([6410b38](https://github.com/iuliandita/skills/commit/6410b386908507c1c388d32cf4f0b4a1374f3cc0))


### Bug Fixes

* **skills:** restore hand-written self-check items removed by label match ([8454716](https://github.com/iuliandita/skills/commit/845471674cfd4585278cdb39f200ba2f844efc7a))


### Documentation

* **skills:** fix first body paragraph as marketplace storefront copy ([#122](https://github.com/iuliandita/skills/issues/122)) ([3bd7d08](https://github.com/iuliandita/skills/commit/3bd7d0835a62fc71a30d8f79290290834a31730e))
* **skills:** use neutral example subnet in networking examples ([2419d79](https://github.com/iuliandita/skills/commit/2419d7974de562f0e418b860bc8276bb88676d22))


### Refactoring

* **skills:** drop injected generic self-check items ([4786b50](https://github.com/iuliandita/skills/commit/4786b50f74724e1cb31be86343f88723838e475b))
* **scripts:** drop unused output-contract back-compat wrappers ([286529b](https://github.com/iuliandita/skills/commit/286529b332e715748a1f1d5a3e2c5d553978acea))

## [1.43.0](https://github.com/iuliandita/skills/compare/v1.42.2...v1.43.0) (2026-07-27)


### Features

* **synology-dsm:** add Synology DSM administration and btrfs recovery skill ([#118](https://github.com/iuliandita/skills/issues/118)) ([8857174](https://github.com/iuliandita/skills/commit/8857174))

## [1.42.2](https://github.com/iuliandita/skills/compare/v1.42.1...v1.42.2) (2026-07-22)


### Bug Fixes

* **virtualization:** validate Packer examples ([#116](https://github.com/iuliandita/skills/issues/116)) ([6d2eabc](https://github.com/iuliandita/skills/commit/6d2eabca54c9a8581c4ba0fd1d5297dde6aaf454))

## [1.42.1](https://github.com/iuliandita/skills/compare/v1.42.0...v1.42.1) (2026-07-22)


### Bug Fixes

* **skills:** refresh July versions and advisories ([#107](https://github.com/iuliandita/skills/issues/107)) ([99f7e84](https://github.com/iuliandita/skills/commit/99f7e84))
* **skills:** resolve collection-wide safety and behavioral gaps ([#112](https://github.com/iuliandita/skills/issues/112)) ([d313b9e](https://github.com/iuliandita/skills/commit/d313b9e))

## [1.42.0](https://github.com/iuliandita/skills/compare/v1.41.0...v1.42.0) (2026-07-13)


### Features

* **deep-grill:** four-outcome model, fog test, fuzzy-term and prototype moves ([#104](https://github.com/iuliandita/skills/issues/104)) ([248322d](https://github.com/iuliandita/skills/commit/248322d))

## [1.41.0](https://github.com/iuliandita/skills/compare/v1.40.0...v1.41.0) (2026-07-12)


### Features

* **code-slimming:** superseded code, leftover files, and AI-bloat shapes ([#102](https://github.com/iuliandita/skills/issues/102)) ([c5fbd94](https://github.com/iuliandita/skills/commit/c5fbd94))

## [1.40.0](https://github.com/iuliandita/skills/compare/v1.39.0...v1.40.0) (2026-06-25)


### Features

* **anti-ai-prose:** add confident-filler, rhetorical-setup, and faux-profundity buckets ([#101](https://github.com/iuliandita/skills/issues/101)) ([cffb928](https://github.com/iuliandita/skills/commit/cffb928))
* **code-slimming:** add dead-code and comment-wall slimming axes ([#98](https://github.com/iuliandita/skills/issues/98)) ([876d7af](https://github.com/iuliandita/skills/commit/876d7af705a0645496be60acddc9da6f05f539f6))


### Bug Fixes

* **code-slimming:** reconcile review inconsistencies + refiner polish ([#100](https://github.com/iuliandita/skills/issues/100)) ([57a61ae](https://github.com/iuliandita/skills/commit/57a61aec67facbfb98b4086d1ff55fa087dacef1))

## [1.39.0](https://github.com/iuliandita/skills/compare/v1.38.1...v1.39.0) (2026-06-14)


### Features

* **debug-triage:** add live-incident layer-localization skill ([#96](https://github.com/iuliandita/skills/issues/96)) ([e08b95d](https://github.com/iuliandita/skills/commit/e08b95d102200305012eeda6583f3a012b667b9e))
* **observability:** add observability/SRE skill as deep-audit Wave 3 lens ([#93](https://github.com/iuliandita/skills/issues/93)) ([839928d](https://github.com/iuliandita/skills/commit/839928d7ea6eeebb46ca2ff4081574fbc7a6dbda))

## [1.38.1](https://github.com/iuliandita/skills/compare/v1.38.0...v1.38.1) (2026-06-14)


### Bug Fixes

* **scripts:** verify cross-skill references instead of trusting bold text ([6c6e8a1](https://github.com/iuliandita/skills/commit/6c6e8a11ce10bd94126488154af705c24a2af436))


### Refactoring

* **scripts:** share name and length checks via skill-lib ([d370ab9](https://github.com/iuliandita/skills/commit/d370ab9acd99a8617d58951ff9bb7ea2d4cf3636))

## [1.38.0](https://github.com/iuliandita/skills/compare/v1.37.0...v1.38.0) (2026-06-14)


### Features

* **skills:** add handoff session-handoff skill ([#82](https://github.com/iuliandita/skills/issues/82)) ([a295e55](https://github.com/iuliandita/skills/commit/a295e5595401046045a1e9811eaccaae27898120))


### Bug Fixes

* **skills:** make output contract self-contained per skill ([#85](https://github.com/iuliandita/skills/issues/85)) ([4a94e9c](https://github.com/iuliandita/skills/commit/4a94e9ce34db1ab66d4884987815199099d0b6cf))
* **skills:** refine handoff after review (commit path, deferred slot, secrets) ([#84](https://github.com/iuliandita/skills/issues/84)) ([4306da3](https://github.com/iuliandita/skills/commit/4306da3ca67457b6ec45073cd94a6425048ecc49))
* **skills:** sharpen full-review vs deep-audit routing separation ([#86](https://github.com/iuliandita/skills/issues/86)) ([9602e91](https://github.com/iuliandita/skills/commit/9602e91d6fa35544d4d4052d19f6ae06a0664abb))

## [1.37.0](https://github.com/iuliandita/skills/compare/v1.36.0...v1.37.0) (2026-06-13)


### Features

* **skills:** add deep-grill plan interrogator skill ([#79](https://github.com/iuliandita/skills/issues/79)) ([bd5a9f7](https://github.com/iuliandita/skills/commit/bd5a9f7e1658292164d27aaa58216b75041278d0))

## [1.36.0](https://github.com/iuliandita/skills/compare/v1.35.0...v1.36.0) (2026-05-29)


### Features

* **skills:** skill-refiner sweep 2026-05-29 (bug fixes, routing, content, lint guard) ([#77](https://github.com/iuliandita/skills/issues/77)) ([a643ede](https://github.com/iuliandita/skills/commit/a643ede7780b80887705250bd1032ab93e40d7a9))


### Bug Fixes

* **skills:** correct technical errors found in full content review ([#75](https://github.com/iuliandita/skills/issues/75)) ([61a8bce](https://github.com/iuliandita/skills/commit/61a8bcec234a9097068428ff94cb26a1b7b22b7a))
* **skills:** refresh CVE/advisory references with recent 2026 incidents ([#76](https://github.com/iuliandita/skills/issues/76)) ([09a8254](https://github.com/iuliandita/skills/commit/09a82548bac517998ddd4de435a89a50435ad546))
* **skills:** refresh stale version pins in databases, ansible, git ([#73](https://github.com/iuliandita/skills/issues/73)) ([3add86a](https://github.com/iuliandita/skills/commit/3add86a5bcbcc598e3e310e5e08c48cedb3f7313))

## [1.35.0](https://github.com/iuliandita/skills/compare/v1.34.1...v1.35.0) (2026-05-28)


### Features

* **skills:** deep-audit remediation - model/version/CVE refresh and contract fixes ([#71](https://github.com/iuliandita/skills/issues/71)) ([3d87ef9](https://github.com/iuliandita/skills/commit/3d87ef9561e37dae62810261aff375da019d530b))

## [1.34.1](https://github.com/iuliandita/skills/compare/v1.34.0...v1.34.1) (2026-05-28)


### Refactoring

* **skills:** finish severity migration and harden self-checks ([9793e1c](https://github.com/iuliandita/skills/commit/9793e1cb0b4b4d8b508b1553aecaeb38408937a1))

## [1.34.0](https://github.com/iuliandita/skills/compare/v1.33.1...v1.34.0) (2026-05-18)


### Features

* **anti-ai-prose:** add adverb crutch, AI fallback names, plan-first rule ([3486ddf](https://github.com/iuliandita/skills/commit/3486ddf3aab5c569eba58a40b4d2478124b0266b))


### Bug Fixes

* **skills:** refresh audit and supply-chain guidance ([3e92070](https://github.com/iuliandita/skills/commit/3e92070bd330ed55692f799a91a47c4576d24ea5))

## [1.33.1](https://github.com/iuliandita/skills/compare/v1.33.0...v1.33.1) (2026-05-03)


### Bug Fixes

* **update-docs:** check stale evidence claims ([27f787b](https://github.com/iuliandita/skills/commit/27f787bd88b7c34e9af5e4b2e860aae92d8f78e4))


### Refactoring

* **skills:** polish audit quality gates ([62a6324](https://github.com/iuliandita/skills/commit/62a632479f35c3652f1222d52d211dd6db3d084f))

## [1.33.0](https://github.com/iuliandita/skills/compare/v1.32.2...v1.33.0) (2026-05-03)


### Features

* **skills:** standardize output contract across all 42 skills ([16aaf12](https://github.com/iuliandita/skills/commit/16aaf12030fc0b609a06a1461c3d0e5337f3a5e0))

## [1.32.2](https://github.com/iuliandita/skills/compare/v1.32.1...v1.32.2) (2026-05-02)


### Bug Fixes

* **installer:** harden skill audit workflow ([2c9ed53](https://github.com/iuliandita/skills/commit/2c9ed538229935483f47ed9c6ec24beaddfb1f3f))

## [1.32.1](https://github.com/iuliandita/skills/compare/v1.32.0...v1.32.1) (2026-05-02)


### Refactoring

* **skills:** consolidate narrow references ([b4745e8](https://github.com/iuliandita/skills/commit/b4745e86989567ee581d69d410c7fe06fc0853b1))

## [1.32.0](https://github.com/iuliandita/skills/compare/v1.31.1...v1.32.0) (2026-05-02)


### Features

* add code slimming skill ([65da7df](https://github.com/iuliandita/skills/commit/65da7dfa1344a0184d1547f5ff77d41b5f1e944a))

## [1.31.1](https://github.com/iuliandita/skills/compare/v1.31.0...v1.31.1) (2026-05-01)


### Documentation

* **skills:** salvage workflow guidance ([a57c933](https://github.com/iuliandita/skills/commit/a57c9333f69eb7d4b73ed1294b367989ac05cc03))

## [1.31.0](https://github.com/iuliandita/skills/compare/v1.30.1...v1.31.0) (2026-05-01)


### Features

* **skills:** grow discovery and publish cluster health ([ada8247](https://github.com/iuliandita/skills/commit/ada8247bd8312d73add0437784fa704fcbc36dd0))

## [1.30.1](https://github.com/iuliandita/skills/compare/v1.30.0...v1.30.1) (2026-04-30)


### Refactoring

* refresh collection quality checks ([275a775](https://github.com/iuliandita/skills/commit/275a775b564c581a5142465399ededc033214f88))

## [1.30.0](https://github.com/iuliandita/skills/compare/v1.29.0...v1.30.0) (2026-04-30)


### Features

* refresh skills for May 2026 ([6f524bc](https://github.com/iuliandita/skills/commit/6f524bc81bf44072309f306c30a2b95f02c348e5))

## [1.29.0](https://github.com/iuliandita/skills/compare/v1.28.1...v1.29.0) (2026-04-28)


### Features

* **frontend-design:** add opinionated UI/UX persona skill ([#41](https://github.com/iuliandita/skills/issues/41)) ([d00cd77](https://github.com/iuliandita/skills/commit/d00cd77877dc4083f8a473ffc4489bec126c9eab))
* **jekyll-hyde:** add dual-lens advisor skill ([#43](https://github.com/iuliandita/skills/issues/43)) ([8192e5f](https://github.com/iuliandita/skills/commit/8192e5f306569de5835f17fe5eae8632d93c7c65))

## [1.28.1](https://github.com/iuliandita/skills/compare/v1.28.0...v1.28.1) (2026-04-25)


### Bug Fixes

* drop find -L in skill_hash + README narrative refresh ([f932f79](https://github.com/iuliandita/skills/commit/f932f7974114f4ece13bfc5e41807bbcbf3670cf))

## [1.28.0](https://github.com/iuliandita/skills/compare/v1.27.0...v1.28.0) (2026-04-25)


### Features

* **ai-ml:** llama.cpp CPU inference + collection-wide quality sweep ([#37](https://github.com/iuliandita/skills/issues/37)) ([e8a2636](https://github.com/iuliandita/skills/commit/e8a263601254082df4a0e62ca9abae1a45f73d2d))

## [1.27.0](https://github.com/iuliandita/skills/compare/v1.26.2...v1.27.0) (2026-04-23)


### Features

* **installer:** add current agent targets ([8949eda](https://github.com/iuliandita/skills/commit/8949edabf4fcfba80a7e690b223235f5fa51b9ac))


### Bug Fixes

* **installer:** include internal skills in linked installs ([ac17dbf](https://github.com/iuliandita/skills/commit/ac17dbfaeefdce270daff7dae64b060537c50e72))

## [1.26.2](https://github.com/iuliandita/skills/compare/v1.26.1...v1.26.2) (2026-04-23)


### Bug Fixes

* **skills:** tighten startup descriptions for Codex budget ([#32](https://github.com/iuliandita/skills/issues/32)) ([3766fb5](https://github.com/iuliandita/skills/commit/3766fb59922e6882fd7e0e079e200126829e2618))

## [1.26.1](https://github.com/iuliandita/skills/compare/v1.26.0...v1.26.1) (2026-04-23)


### Bug Fixes

* **routing:** wire new distro and routine skills into reference matrix ([#30](https://github.com/iuliandita/skills/issues/30)) ([6739e1f](https://github.com/iuliandita/skills/commit/6739e1f1e770c7409bbd5326548095dec3d2e19d))

## [1.26.0](https://github.com/iuliandita/skills/compare/v1.25.0...v1.26.0) (2026-04-23)


### Features

* **debian-ubuntu:** emphasize Ubuntu 26.04 upgrade deltas ([#28](https://github.com/iuliandita/skills/issues/28)) ([f54c73e](https://github.com/iuliandita/skills/commit/f54c73ea7eb07948f319d25125098b4e22763b4f))

## [1.25.0](https://github.com/iuliandita/skills/compare/v1.24.0...v1.25.0) (2026-04-23)


### Features

* **nixos-btw:** add NixOS, Nix, flakes, and nix-darwin skill ([#26](https://github.com/iuliandita/skills/issues/26)) ([e6362c4](https://github.com/iuliandita/skills/commit/e6362c4afc2a23da4843bb371ffa02c98ffe85f1))

## [1.24.0](https://github.com/iuliandita/skills/compare/v1.23.0...v1.24.0) (2026-04-22)


### Features

* **kali-linux:** add Kali distro admin skill ([#24](https://github.com/iuliandita/skills/issues/24)) ([4a819eb](https://github.com/iuliandita/skills/commit/4a819eba6b20a4d23cbff9e8cc8a99cdd53dd6c8))

## [1.23.0](https://github.com/iuliandita/skills/compare/v1.22.0...v1.23.0) (2026-04-22)


### Features

* **deep-audit:** persist findings and generate phased task list ([#21](https://github.com/iuliandita/skills/issues/21)) ([155e0c0](https://github.com/iuliandita/skills/commit/155e0c0c9e25b72d39e84324121f6128ad4fd793))
* **skills:** add debian and rpm distro admin skills ([#23](https://github.com/iuliandita/skills/issues/23)) ([087994a](https://github.com/iuliandita/skills/commit/087994a01a787809f2e2bd8f368121699885912a))


### Refactoring

* **skill-refiner:** 2026-04-16 run - avg 97.1 &gt; 98.0 across 32 skills ([#19](https://github.com/iuliandita/skills/issues/19)) ([e256d3f](https://github.com/iuliandita/skills/commit/e256d3fe01e12350fe19ceb7b9d55d01634acf02))

## [1.22.0](https://github.com/iuliandita/skills/compare/v1.21.0...v1.22.0) (2026-04-16)


### Features

* **git, ci-cd:** add forgejo-cli, Gitea/Woodpecker CI, runners, best-practices ([#17](https://github.com/iuliandita/skills/issues/17)) ([4777d3b](https://github.com/iuliandita/skills/commit/4777d3b8d793fb636c5b29d7bc09850b68079c9b))

## [1.21.0](https://github.com/iuliandita/skills/compare/v1.20.0...v1.21.0) (2026-04-14)


### Features

* **release:** automate releases with release-please ([#15](https://github.com/iuliandita/skills/issues/15)) ([4a19864](https://github.com/iuliandita/skills/commit/4a1986475f0857b46ee10e7f13fe9e0419205fd4))
* **routine-writer:** add skill for Claude Code routines ([#14](https://github.com/iuliandita/skills/issues/14)) ([0e6736f](https://github.com/iuliandita/skills/commit/0e6736facf3bf5db8a8536e64d0365f28302374f))


### Refactoring

* **anti-slop:** surface structural duplication findings ([#13](https://github.com/iuliandita/skills/issues/13)) ([2252cc9](https://github.com/iuliandita/skills/commit/2252cc928a390bc675a02a40a59f97236a4ba2ae))
* **anti-slop:** tighten AI-specific smell detection ([#11](https://github.com/iuliandita/skills/issues/11)) ([ef3bbae](https://github.com/iuliandita/skills/commit/ef3bbae8b59b8c697f2072865e9637ce5718c712))

## [1.20.0](https://github.com/iuliandita/skills/releases/tag/v1.20.0) (2026-04-14)

### Miscellaneous

- Bootstrap baseline before release-please automation.
