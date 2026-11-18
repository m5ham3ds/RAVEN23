# PHASE63.27.3 — JVM-safe download link format inference (2026-11-17)

## Confirmed CI failure

This repair is based on the `RAVEN23_PHASE63.27.2_PRESS_FEEDBACK_SCALE_RESTORE.zip` project and the uploaded diagnostics for GitHub Actions run `43973265345`, commit `3bcb105eaede282c7add70d49244007be07c6643`. No Zangetsu, FlixQuest or OpenStream archive was inspected or changed. Firebase and backend work remain out of scope.

The run passed dependency resolution, scoped Dart formatting (159 targets, zero formatting changes), Flutter Analyze, all 200 focused Flutter test cases, and Gradle wrapper generation. The focused Android task then ran seven JUnit cases: all three Mihon ABI cases passed, and three of four download/player contract cases passed. The remaining case failed:

```text
StreamDownloadStorePlayerContractTest > refreshedLinksRespectDeclaredContainerForOpaqueSignedUrls FAILED
java.lang.RuntimeException: Method parse in android.net.Uri not mocked.
at android.net.Uri.parse(Uri.java)
at com.m5ham3ds.raven23.downloads.DownloadSourceResolverKt.downloadLinkFormat(DownloadSourceResolver.kt:28)
```

The failure prevented the Release APK build and APK ABI audit from running. It was not a Flutter analysis, Dart formatting, Media3 compilation, or APK packaging failure.

## Root cause

`downloadLinkFormat()` is a deterministic URL/container classification helper exercised by a plain local JVM unit test. When neither `isM3u8` nor `isDash` nor an explicit `streamContainer` determines the type, its path-suffix fallback called `android.net.Uri.parse()`. The test class does not use Robolectric, so the Android framework method is intentionally unavailable in that JVM test environment. This made a platform-independent classification test depend unnecessarily on an Android runtime.

## Repair

- Replace only the helper's path extraction with `java.net.URI(url).path`, falling back to `java.net.URL(url).path` for provider URLs that contain characters rejected by strict URI parsing.
- Continue lowercasing the path before suffix comparison; query strings and fragments remain excluded from the path.
- Preserve the existing precedence: explicit HLS/DASH flags first, declared `streamContainer` second, and URL path suffix inference last.
- Extend the existing focused contract test with uppercase MP4, WebM, signed query/fragment, and extensionless progressive URL cases. The test method name and the four-case CI contract remain unchanged.
- Do not change Android `Uri` usage in the actual resolver/network request paths, download recovery, headers, cache, or Media3 downloader implementation.

## Validation boundary

The uploaded CI evidence is preserved under `docs/build-reports/2026-11-16-phase63.27.2-run-43973265345/`. Source-level validation for this repair checks the exact modified files, the standalone URL-path behavior, workflow YAML and archive integrity. Flutter/Dart and the Android Gradle toolchain are unavailable in this editing environment; no full Gradle unit-test run, Flutter test run, Release APK, or device test is claimed. A new CI run must pass all seven Android cases and create the ARM64 Release APK before this phase is accepted.
