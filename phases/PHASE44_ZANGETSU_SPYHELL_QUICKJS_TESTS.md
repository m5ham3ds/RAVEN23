# Phase 44 — Tests and Validation

## Added targeted tests

File: `test/video_providers/phase44_quickjs_catalog_test.dart`

- The six bundled repositories remain unique and catalog-only; the historical `index.ison` typo is not introduced.
- Zangetsu declarations preserve type and explicit/missing `nsfw` metadata.
- Known Live TV channel-group providers are rejected by VOD `supportsMedia`; a normal Movie provider remains eligible.
- Archive role is retained without claiming playback verification or rights clearance.
- Serenity mixed scripts remain declared Movie until a separate Series contract is tested.
- Credential-backed source candidates are visibly flagged for review.
- Beta lifecycle status (0–3), explicit fallback flags and fallback tags remain preserved for Zangetsu `sources` entries.
- Duplicate candidates are reported by canonical script URL while both alternatives remain present.

## Existing tests required with Phase 44

- `source_repository_parser_test.dart`
- `quickjs_source_engine_test.dart`
- `quickjs_extension_settings_test.dart`
- `quickjs_bridge_security_test.dart`

## Not claimed

No live JavaScript source was executed during packaging. No real account-backed provider credentials were used. No external host was marked playback-verified. Cloudflare/Turnstile or other access controls are not bypassed. Archive labels are not legal review.

Dart/Flutter formatting, analyze, test execution and Android device playback remain pending until the combined Phase 44/45 CI run.
