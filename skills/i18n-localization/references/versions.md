---
checked_at: "2026-10-02"
checked_by: "migration"
pins:
  - tool: "react-i18next"
    version: "17.0.15"
    source: "https://www.npmjs.com/package/react-i18next"
  - tool: "vue-i18n"
    version: "11.4.13"
    source: "https://www.npmjs.com/package/vue-i18n"
  - tool: "next-intl"
    version: "4.14.9"
    source: "https://www.npmjs.com/package/next-intl"
  - tool: "i18next"
    version: "26.4.2"
    source: "https://www.npmjs.com/package/i18next"
  - tool: "i18next-http-middleware"
    version: "3.9.9"
    source: "https://github.com/i18next/i18next-http-middleware/security/advisories/GHSA-r4j4-5cw9-pwgj"
  - tool: "i18next-fs-backend"
    version: "2.6.8"
    source: "https://github.com/i18next/i18next-fs-backend/security/advisories/GHSA-cchx-rhgv-92hj"
---

# i18n target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled October 2026
(npm latest on 2026-10-02). Reverify before use if the receipt exceeds 120 days.

| Package | Version |
|---|---|
| react-i18next | 17.0.15 |
| vue-i18n | 11.4.13 |
| next-intl | 4.14.9 |
| i18next | 26.4.2 |
| i18next-http-middleware (missing-key persistence) | 3.9.9 |
| i18next-fs-backend (missing-key persistence) | 2.6.8 |

## Security floors (advisory ranges checked 2026-10-02)

Require at least the following verified security fixes: critical missing-key prototype-pollution
fixes first shipped in middleware 3.9.7 ([CVE-2026-48714](https://github.com/i18next/i18next-http-middleware/security/advisories/GHSA-f49m-vf83-692w), affected <3.9.7)
and filesystem backend 2.6.6 ([CVE-2026-48713](https://github.com/i18next/i18next-fs-backend/security/advisories/GHSA-2933-q333-qg83), affected <2.6.6).
Later high-severity prototype-pollution fixes raise the floors to middleware 3.9.9
([GHSA-r4j4-5cw9-pwgj](https://github.com/i18next/i18next-http-middleware/security/advisories/GHSA-r4j4-5cw9-pwgj), affected <=3.9.8)
and filesystem backend 2.6.8 ([GHSA-cchx-rhgv-92hj](https://github.com/i18next/i18next-fs-backend/security/advisories/GHSA-cchx-rhgv-92hj), affected <=2.6.7).
Do not expose missing-key persistence to untrusted users; disable `saveMissing` where unnecessary.
