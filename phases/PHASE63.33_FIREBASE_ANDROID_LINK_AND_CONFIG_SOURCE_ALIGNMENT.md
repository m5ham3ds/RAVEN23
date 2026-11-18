# RAVEN23 — PHASE63.33 Firebase Android Link & Config-Source Alignment

## Firebase Android registration

- Firebase project: `raven23-m5ham3ds`
- Android application ID: `com.m5ham3d.raven23`
- Android Firebase App ID: `1:1021333219041:android:80b9e74afc40e9955c39a0`
- Configuration: `android/app/google-services.json`
- Gradle dialect: Groovy (`build.gradle`), not Kotlin DSL.

## Changes

1. Add the supplied Google services configuration at the Android app module path.
2. Use current documented Google Services and Crashlytics Gradle plugin versions in the root Groovy buildscript.
3. Enable the Android Firebase Gradle plugins in CI so the Google services JSON is processed and verified during the APK build.
4. Keep the Dart Firebase runtime disabled in the CI development APK (`ENABLE_FIREBASE=false`, `LOCAL_DEV_MODE=true`) until a production Laravel API URL and rollout settings are configured. This avoids accidentally enabling Laravel auth/sync/ads against the example emulator URL.
5. Correct the APK audit to validate the requested `applicationId`, `com.m5ham3d.raven23`, while preserving the internal namespace and Kotlin package `com.m5ham3ds.raven23`.
6. Retire Firebase Remote Config's old application-update fields from the current Firebase snapshot mapper. Current app-update version, force/min-build rules, APK URLs and changelog remain sourced from the selected Laravel bootstrap `updates` object.
7. Add regression coverage proving that legacy Firebase update keys, including ABI-specific download URLs, cannot reactivate the retired update path.

## Important rollout gate

The Android app is registered and the native Google services configuration is wired. The full Dart Firebase runtime is intentionally not switched on in this phase. Before that rollout, configure a production `LARAVEL_API_URL` (or publish the equivalent `laravel_api_url` Remote Config value) and confirm the backend's `config_source` decision. The example `.env` URL `http://10.0.2.2:8000` is an emulator address, not a production phone/TV endpoint.

## Validation

CI must confirm:
- Flutter analysis and focused tests pass.
- Firebase Google services plugin processes `android/app/google-services.json`.
- The ARM64 APK package is `com.m5ham3d.raven23`.
- Existing app-update tests and Laravel-selected update configuration remain intact.

This phase must not be marked build-confirmed until the new GitHub Actions run completes successfully.
