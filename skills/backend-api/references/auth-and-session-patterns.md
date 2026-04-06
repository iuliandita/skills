# Auth and Session Patterns

Use this file when the main skill needs current HTTP API auth guidance.

## Start From the Client Type

| Client | Default | Avoid by default |
|--------|---------|------------------|
| First-party browser SPA or web app | Session cookie or BFF/token-mediating backend | Long-lived bearer tokens in browser storage |
| Native/mobile app | OAuth/OIDC authorization code + PKCE | Implicit flow |
| Third-party server integration | OAuth 2.0 client credentials or scoped API keys | Reusing user tokens for machine work |
| Internal service | Platform workload identity, mTLS, or short-lived service credentials | User login flows between services |

## Sessions vs Bearer Tokens

### Prefer sessions when:
- The client is a first-party browser app
- The backend can hold server-side session state or issue tightly scoped session cookies
- You want the browser to act like a browser instead of a token vault

Cookie baseline:
- `HttpOnly`
- `Secure`
- `SameSite=Lax` or `SameSite=Strict` unless the flow truly needs cross-site behavior
- CSRF defenses that match the app's cookie and cross-site behavior, not just "SameSite should handle it"
- Short idle and absolute lifetimes

### Prefer bearer tokens when:
- The client is native, mobile, CLI, or third-party server software
- The client legitimately needs to call multiple resource servers
- Delegated authorization matters more than server-side session control

Bearer token rules:
- Keep access tokens short-lived
- Rotate or sender-constrain refresh tokens where the platform supports it
- Scope tokens narrowly
- Never assume JWT means "safe" or "stateless enough"

## OAuth/OIDC Rules

Current baseline:
- Use authorization code + PKCE for public clients
- Do not use the implicit flow
- Do not use the resource owner password credentials grant

OIDC note:
- Use OIDC when the client needs verified user identity claims, not as a synonym for every OAuth-protected API

Important nuance:
- "OAuth 2.1" is still draft territory; anchor guidance on RFC 9700 and current browser-app BCP work instead of pretending a final OAuth 2.1 RFC already exists

If the request says "JWT auth", do not stop at the token format. Determine:
- Who issues the token?
- Who stores it?
- How is it refreshed?
- What revokes it?
- What audience and scopes are enforced?

## BFF / Token-Mediating Backend

For first-party browser apps that rely on OAuth/OIDC with an external IdP, the BFF or
token-mediating backend pattern is often the safest default.

Why:
- Tokens stay on the server side or are minimized in the browser
- Sensitive token exchange logic moves out of browser JavaScript
- Session cookies can represent the browser-facing auth state

Good fit:
- React, Vue, or other SPAs that talk mostly to one backend
- Admin apps
- Internal business apps

Tradeoff:
- More backend coordination
- Extra network hop if every request is fully proxied

## API Keys

API keys are machine credentials, not universal auth.

Reasonable uses:
- Internal automation
- Server-to-server integrations
- Simple third-party integrations with low delegation needs

Rules:
- Scope keys to an account or integration
- Store only hashed keys server-side when possible
- Allow rotation and revocation
- Rate limit by key
- Do not overload one key with human and machine privileges
- Do not issue browser-facing API keys to first-party web apps as a lazy substitute for sessions or OAuth

## Refresh Tokens

Refresh tokens need stricter handling than access tokens.

Rules:
- Issue them only when the client type and session model justify them
- Rotate them for public clients where supported
- Detect replay where the identity platform allows it
- Revoke on logout, credential change, or high-risk events

## Authorization Boundaries

Authentication answers "who are you?"
Authorization answers "can you do this?"

Check authorization at the right boundary:
- Route or guard level for coarse access
- Service or domain layer for object-level rules
- Never trust client-supplied tenant IDs, roles, or ownership hints
- Decide whether out-of-scope resources are hidden with `404` or exposed with `403`, then keep that rule consistent across the boundary

Common mistake:
- Valid token present
- Resource ownership never checked
- Result: authenticated users can access the wrong tenant's data

That is not a design nit. That is a security bug. Route follow-up review to **security-audit**.
