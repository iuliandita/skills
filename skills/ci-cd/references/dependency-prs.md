# Dependency update PR triage

1. Identify the current and proposed versions, direct and transitive dependencies, and every
   update in the group. Read upstream changelogs and release notes for the entire interval;
   check migration instructions, compatibility requirements, deprecations, and security fixes.
2. Find affected callers, configuration, generated artifacts, and runtime environments. Trace
   indirect use when a dependency supplies a plugin, action, compiler, or build tool.
3. Choose and run a behavioral check that exercises the affected path with the new version.
   A passing install or lint alone does not prove runtime behavior. Record checks that could
   not run and the remaining risk.
4. Before merging, confirm required CI and review gates pass, the lockfile matches the
   manifest and intended resolver, and the PR contains no unrelated lockfile changes. For
   grouped updates, assess each dependency and split the group if failures or risk cannot be
   attributed confidently.
5. Close superseded, incompatible, or unnecessary updates with the reason and follow-up.
   Pin or defer a version when a verified incompatibility or regression blocks the bump;
   record an owner, reason, and revisit date. Do not pin away a security fix without assessing
   exposure and a mitigation. Follow the repository's merge and authorization policy.
