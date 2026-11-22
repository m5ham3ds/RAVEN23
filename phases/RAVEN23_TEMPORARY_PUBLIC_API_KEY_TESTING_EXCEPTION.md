# RAVEN23 — Temporary Public API-Key Testing Exception

**Status:** ACTIVE — explicitly owner-authorized temporary development exception  
**Authorized:** 2026-11-22  
**Applies to:** the existing TMDB v3, OpenSubtitles API v1, and SubSource API v1 test values in the tracked `.env.example` file.

## 1. Owner authorization

The project owner has explicitly confirmed that the existing test keys are knowingly exposed and must remain available in `.env.example` while Android phone testing and modification validation continue.

Until the owner explicitly confirms that phone testing is complete:

- Do not blank, delete, remove, rotate, replace, or migrate the existing TMDB, OpenSubtitles, or SubSource values.
- Do not revert `.env.example` to a blank-key template.
- Do not move these values to the server early or change the current phone-testing configuration without a new owner instruction.
- Preserve the same current values when updating the working branch or rebuilding the test APK.

This owner instruction supersedes any earlier phase note that recommended blanking or removing the existing OpenSubtitles/SubSource test values.

## 2. Explicitly accepted exposure and strict limits

The owner understands that:

- `.env.example` is tracked in a public Git repository.
- GitHub Actions copies `.env.example` to `.env`.
- `pubspec.yaml` bundles `.env` as an application asset.
- Consequently, the configured values are publicly visible in Git and can be extracted from built APKs; removing a value from a later commit does not erase its prior Git history.

This exception is limited to development and the owner's phone testing. It does **not** authorize use of these values for production traffic, production releases, customer deployments, or any privileged account operation. Do not add additional credentials or widen the exception beyond the named existing values.

## 3. Handling and logging restrictions

- Never echo actual key values into CI logs, terminal output, build reports, test diagnostics, screenshots, phase documents, commit messages, or chat replies.
- Diagnostics may include variable names, masked identifiers, HTTP status codes, quota headers, and pass/fail outcomes only.
- Respect each provider's terms, free quotas, rate limits, and key-sharing rules. Do not rotate keys or create extra accounts to evade quota limits.
- Do not place primary account passwords, session cookies, or account recovery data in the app.
- `ARABICSUBS_API_KEY` is not covered by this exception. ArabicSubs' Bearer key remains server-only. The mobile app may contain only `ARABICSUBS_PROXY_URL` pointing at the protected proxy.

## 4. Owner-only closure and migration gate

Only after the owner explicitly confirms that phone testing is complete may the project:

1. migrate the credentials needed for production to protected server-side configuration;
2. remove the temporary values from the public `.env.example` and the APK asset path;
3. validate that no client build contains provider secrets; and
4. record the completed migration/removal in this policy and Phase64.

No automated cleanup, CI job, refactor, security sweep, or unrelated phase may silently close this exception.

## 5. Relationship to Phase64

This policy is binding for `PHASE64.0–64.6` provider research, adapters, testing, and selector validation. It does not relax provider terms, quotas, the ArabicSubs server-only restriction, the protected-feature guardrails, or the acceptance gates for Phase64.4–64.7.
