# Authenticated Browsing

## User Consent

Use account context only when the user asked for an authenticated page or explicitly approved using
an existing session. Authentication grants read access, not broad permission to mutate account
state.

## Session Reuse

Reuse a session for a single task flow. Before acting, verify which account, tenant, workspace, or
organization is active if the page exposes that information.

## Cookie Isolation

Clear cookies, local storage, and session storage between unrelated accounts or tenants. Do not mix
personal and work sessions in one browser context.

## CSRF-Sensitive Actions

Authentication grants read access, not permission to mutate account state. Treat saves, deletes,
purchases, posts, messages, and permission changes as destructive unless the user explicitly asked
for that exact action.

## Multi-Tenant Accounts

Confirm the tenant selector, organization name, or workspace before extracting tenant-specific
data. If the target tenant is ambiguous, ask rather than guessing from the current page.

## Cleanup

After the task, close the browser context or clear storage when the session is no longer needed.
Never print cookies, bearer tokens, CSRF tokens, or recovery codes in the final answer.
