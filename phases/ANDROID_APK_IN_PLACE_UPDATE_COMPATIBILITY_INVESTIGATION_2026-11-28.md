# RAVEN23 — Android APK In-Place Update Compatibility Investigation

**Audit date:** 2026-11-28  
**Repository:** `m5ham3ds/RAVEN23`  
**Branch / inspected source ref:** `main` @ `387feafb4865d991223897088b82eacb7a42061a`  
**Latest inspected CI:** [Run #320 — success](https://github.com/m5ham3ds/RAVEN23/actions/runs/46053675384)  
**Disposition:** **Confirmed release-update compatibility defects.** The repository does not currently guarantee that every APK can replace every previously installed RAVEN23 build. The exact device-side installer error remains unverified because no Android Package Installer error code or prior installed APK was available during this audit.

## 1. Executive conclusion

The investigation found three distinct update-identity/versioning concerns:

1. **The Android application ID was changed.** Before the 2026-11-18 identity change, the Gradle application ID was `com.m5ham3ds.raven23`. Commit [`6a12ce3`](https://github.com/m5ham3ds/RAVEN23/commit/6a12ce3a2d32069c90851042a6a6628ed1b2be83) changed it to `com.m5ham3d.raven23` (the `s` after `m5ham3d` was removed) to align with the Firebase Android registration. Android identifies an installed application by its application ID. An APK with the new ID is not an in-place update of an installation using the old ID; it is a different app identity. This is a confirmed compatibility break for installations created with the old ID.

2. **The build number is fixed at 12.** `pubspec.yaml` declares `version: 4.4.0+12`; `android/app/build.gradle` reads Flutter's `flutter.versionCode` and deliberately overrides variant output version codes with that same value. The actual APK metadata from both CI #319 and CI #320 reports `versionName=4.4.0` and `versionCode=12`. Consecutive builds therefore do not receive a higher Android version code. This is a confirmed release-versioning defect and can cause a downgrade rejection whenever the installed APK has a version code greater than 12. Equal version codes alone do not establish the cause of a given installation failure, but Android's release guidance says each successive release should use a greater version code.

3. **The recent CI signing identity is stable across the two inspected builds.** Both #319 and #320 restored the same GitHub Actions cache key, `raven23-debug-signing-v1-m5ham3ds/RAVEN23`, and reported the same CI keystore SHA-1 fingerprint. The workflow explicitly passes `-PciDevelopmentSigning=true`, so these two builds use the cached CI development keystore. This rules out a signing-certificate change between these two consecutive runs. It does not prove that an APK installed from an earlier period used that same certificate, and relying on an evictable Actions cache as the sole long-term keystore is not a robust release-key strategy.

**Therefore:** the update problem is real at the repository/configuration level. The strongest confirmed break for older installations is the application-ID migration; the fixed version code is a second confirmed defect. A device-side error code is still required to decide whether the particular failed attempt was rejected for a package/signature mismatch, a version downgrade, or another installer condition.

## 2. Evidence examined

### 2.1 Application identity changed

Current source:

- `android/app/build.gradle`: `namespace 'com.m5ham3ds.raven23'`.
- `android/app/build.gradle`: current `defaultConfig.applicationId` is `com.m5ham3d.raven23`.
- `android/app/src/main/AndroidManifest.xml`: the manifest's legacy `package` attribute remains `com.m5ham3ds.raven23`; the explicit Gradle `applicationId` determines the installed app identity for the built variant.
- The CI #320 APK audit prints `package: name='com.m5ham3d.raven23'`.

Historical change:

- Commit [`6a12ce3`](https://github.com/m5ham3ds/RAVEN23/commit/6a12ce3a2d32069c90851042a6a6628ed1b2be83) changed `applicationId` from `com.m5ham3ds.raven23` to `com.m5ham3d.raven23`.
- The old and new IDs are not interchangeable. Keeping the Kotlin namespace or manifest package at the former value does not make an APK with the new application ID an update of an app installed under the old ID.

### 2.2 Android version metadata does not advance

- `pubspec.yaml`: `version: 4.4.0+12`.
- `android/app/build.gradle`: `versionCode flutterVersionCode.toInteger()`; if Flutter's local property is absent, the script falls back to `1`.
- The same Gradle file sets `output.versionCodeOverride = flutterVersionCode.toInteger()`, so ABI/output processing does not create a higher release code.
- CI #319 and #320 both report `versionCode='12'` and `versionName='4.4.0'` in their `aapt dump badging` output.

The workflow's GitHub run number (for example, #320) is not currently used as the Android version code.

### 2.3 Signing continuity in recent CI

- `.github/workflows/android-ci.yml` restores `~/.android/debug.keystore` with the cache key `raven23-debug-signing-v1-${github.repository}`.
- The workflow creates a debug keystore only when the cached file is absent.
- The APK build command explicitly sets `-PciDevelopmentSigning=true`.
- CI #319 and #320 both show a cache hit and restore from the same cache key.
- Both runs report the same CI keystore SHA-1 fingerprint (the value is intentionally not repeated here).
- The workflow labels this as a **development/testing signing identity**, not a production distribution key.

This is positive evidence for continuity between the latest two builds, but it is not a guarantee against future cache loss, cache-key changes, or earlier installed APKs signed by a different key. A production-grade update channel should use one explicitly managed, durable signing key and fail closed if it is unavailable rather than silently generating a replacement.

### 2.4 CI success does not prove upgrade installation

CI #320 completed successfully and uploaded the ARM64 APK artifact `RAVEN23-apk.apk`. Its APK audit validates the package name and ABI payload, but the workflow does not install the previous released APK on an Android device and then run `adb install -r` with the new APK while retaining the installed app's data.

Thus, a successful compile, test suite, APK audit, and artifact upload are not proof that an existing user installation can be upgraded in place.

## 3. What is and is not proven

| Question | Audit result |
|---|---|
| Does the current repository preserve one application ID across its history? | **No.** The application ID changed on 2026-11-18. |
| Do the last two inspected CI builds have the same package ID? | **Yes.** Both build `com.m5ham3d.raven23`. |
| Does every new CI build advance Android's version code? | **No.** #319 and #320 both produced `12`. |
| Did the signing identity change between CI #319 and #320? | **No evidence of a change.** Both restored the same cached key and reported the same fingerprint. |
| Is the signing identity proven to match every APK the user has ever installed? | **No.** The older installed APK was not available for certificate comparison. |
| Was the exact phone installation error reproduced? | **No.** No installer error code or device installation log was supplied. |
| Does CI currently test replacement of an installed release APK? | **No.** There is no old-APK-to-new-APK in-place install test in the inspected workflow. |

Useful Android installer failure distinctions:

- `INSTALL_FAILED_UPDATE_INCOMPATIBLE` usually points to a package/signature identity conflict.
- `INSTALL_FAILED_VERSION_DOWNGRADE` points to the new APK having a lower version code than the installed APK.
- A different application ID represents a different app identity; it is not a valid update path for the old package.

The exact error string should be captured before attributing a particular phone failure to only one of these conditions.

## 4. Required remediation before declaring updates fixed

These are the required engineering actions identified by this investigation; **they are not implemented by this documentation-only commit**.

1. **Select and freeze the canonical application ID.** First establish the package ID of the version users currently have installed. If the supported installed population uses `com.m5ham3ds.raven23`, the update path must retain that exact ID and the Firebase Android registration/configuration must be reconciled deliberately. If the intended permanent identity is `com.m5ham3d.raven23`, older-ID installations need an explicit migration/transition plan; changing the Gradle string again without that plan is unsafe. Once selected, add a CI guard preventing an unapproved identity change.

2. **Use one durable signing key for all update builds.** Move the approved long-lived release keystore into protected GitHub Actions secrets (or an equivalent durable secret store), and configure Release signing to use it explicitly. Do not generate a new key automatically when the secret is missing. Record and verify the expected certificate fingerprint in CI. Keep the current CI debug key development-only; do not silently promote it as the production key.

3. **Make Android version codes monotonically increase.** Give every distributed build a unique integer greater than the highest version code already distributed to users. A workflow run number can be used after establishing a safe starting value above the deployed baseline. Keep the user-visible `versionName` separate from the internal integer `versionCode`; do not pin all builds to `12`.

4. **Add an explicit update-compatibility CI gate.** For each candidate APK, assert the canonical application ID, increasing version code, expected signing-certificate fingerprint, and expected ABI. Keep a previous known-good APK as the installed baseline in an Android test/emulator job, install it, then install the new APK with replacement semantics (`adb install -r`) without uninstalling the old version. Verify the app launches and that representative app data remains available.

5. **Capture installer evidence when the gate fails.** Preserve `adb install -r` output and the package manager's failure code in the CI artifact so a future failure is classified as package/signature, downgrade, ABI, parse, or another concrete condition.

## 5. Scope of this commit

This investigation changes documentation only:

- Adds this dedicated investigation report.
- Adds a link and current issue summary to `phases/README_MASTER_IMPLEMENTATION.md`.

It does **not** change `applicationId`, `namespace`, `pubspec.yaml`, Gradle version logic, signing configuration, Firebase configuration, the Android manifest, application source, or the CI workflow. No existing installed user data or app build is modified.

## 6. References

Repository evidence:

- [Application-ID change — commit 6a12ce3](https://github.com/m5ham3ds/RAVEN23/commit/6a12ce3a2d32069c90851042a6a6628ed1b2be83)
- [Current Android Gradle configuration](https://github.com/m5ham3ds/RAVEN23/blob/main/android/app/build.gradle)
- [Current Flutter version declaration](https://github.com/m5ham3ds/RAVEN23/blob/main/pubspec.yaml)
- [Android CI workflow](https://github.com/m5ham3ds/RAVEN23/blob/main/.github/workflows/android-ci.yml)
- [CI #319](https://github.com/m5ham3ds/RAVEN23/actions/runs/46050802426)
- [CI #320](https://github.com/m5ham3ds/RAVEN23/actions/runs/46053675384)

Android platform guidance:

- [Android Developers — Configure the app module / application ID](https://developer.android.com/build/configure-app-module)
- [Android Developers — Version your app / versionCode](https://developer.android.com/studio/publish/versioning)
- [Android Developers — Sign your app / signing certificate continuity](https://developer.android.com/studio/publish/app-signing)

---

**Final audit status:** **OPEN — release update compatibility must be repaired and verified by an actual in-place upgrade test before the issue can be marked resolved.**
