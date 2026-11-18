# APK size and ABI audit

- Artifact: `RAVEN23-apk.apk`
- Build mode: **RELEASE**
- APK size: **45.33 MiB** (47,533,758 bytes)
- Native ABIs found: **arm64-v8a**
- Required native ABIs: **arm64-v8a only**
- Build target: `android-arm64` (single APK; no split-per-ABI)

## Native library payload by ABI

| ABI | .so files | Compressed in APK | Uncompressed |
|---|---:|---:|---:|
| `arm64-v8a` | 6 | 18.93 MiB | 44.52 MiB |

## Payload by category

| Category | Compressed in APK | Uncompressed |
|---|---:|---:|
| Native libraries (arm64-v8a) | 18.93 MiB | 44.52 MiB |
| DEX bytecode | 14.82 MiB | 39.87 MiB |
| Flutter/assets | 6.18 MiB | 7.30 MiB |
| Android resources | 4.95 MiB | 5.95 MiB |
| Other | 0.03 MiB | 0.11 MiB |
| META-INF | 0.02 MiB | 0.05 MiB |

## Largest native libraries

| ABI | Library | Compressed | Uncompressed |
|---|---|---:|---:|
| `arm64-v8a` | `libapp.so` | 6.85 MiB | 16.69 MiB |
| `arm64-v8a` | `libtranslate_jni.so` | 6.47 MiB | 15.60 MiB |
| `arm64-v8a` | `libflutter.so` | 4.93 MiB | 10.53 MiB |
| `arm64-v8a` | `libfastdev_quickjs_runtime.so` | 0.41 MiB | 1.00 MiB |
| `arm64-v8a` | `libzstd-kmp.so` | 0.26 MiB | 0.70 MiB |
| `arm64-v8a` | `libdatastore_shared_counter.so` | 0.00 MiB | 0.01 MiB |

## Largest APK entries

| Entry | Compressed | Uncompressed |
|---|---:|---:|
| `lib/arm64-v8a/libapp.so` | 6.85 MiB | 16.69 MiB |
| `lib/arm64-v8a/libtranslate_jni.so` | 6.47 MiB | 15.60 MiB |
| `lib/arm64-v8a/libflutter.so` | 4.93 MiB | 10.53 MiB |
| `classes4.dex` | 3.45 MiB | 8.67 MiB |
| `classes.dex` | 3.11 MiB | 8.58 MiB |
| `classes6.dex` | 3.04 MiB | 8.34 MiB |
| `classes5.dex` | 2.92 MiB | 7.84 MiB |
| `classes7.dex` | 2.19 MiB | 6.18 MiB |
| `resources.arsc` | 2.22 MiB | 2.22 MiB |
| `lib/arm64-v8a/libfastdev_quickjs_runtime.so` | 0.41 MiB | 1.00 MiB |
| `assets/flutter_assets/assets/images/logo.png` | 0.86 MiB | 0.86 MiB |
| `assets/flutter_assets/assets/images/splash_logo.png` | 0.86 MiB | 0.86 MiB |
| `assets/flutter_assets/assets/images/grid_final.jpg` | 0.78 MiB | 0.78 MiB |
| `lib/arm64-v8a/libzstd-kmp.so` | 0.26 MiB | 0.70 MiB |
| `assets/flutter_assets/assets/images/warner_bros.png` | 0.28 MiB | 0.28 MiB |
| `assets/flutter_assets/assets/images/404.png` | 0.28 MiB | 0.28 MiB |
| `assets/flutter_assets/assets/images/series.png` | 0.28 MiB | 0.28 MiB |
| `classes3.dex` | 0.11 MiB | 0.26 MiB |
| `assets/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf` | 0.11 MiB | 0.25 MiB |
| `assets/flutter_assets/assets/images/sample_frame.jpg` | 0.23 MiB | 0.23 MiB |
| `assets/flutter_assets/assets/translations/hi.json` | 0.04 MiB | 0.22 MiB |
| `res/3o1.png` | 0.21 MiB | 0.21 MiB |
| `res/5l.png` | 0.21 MiB | 0.21 MiB |
| `res/AE.png` | 0.21 MiB | 0.21 MiB |
| `assets/flutter_assets/assets/translations/ar.json` | 0.04 MiB | 0.17 MiB |
