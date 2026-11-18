/*
 * Copyright 2015 Javier Tomás
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Adapted from the Mihon project (https://github.com/mihonapp/mihon)
 * for host-side extension loading adapted for RAVEN23.
 */
package com.m5ham3ds.raven23.mihon

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.os.Build
import android.content.pm.Signature
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.util.Base64
import com.m5ham3ds.raven23.mihon.RavenMihonInjektModules
import java.security.MessageDigest
import dalvik.system.DexClassLoader
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.SourceFactory
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * A loaded Mihon manga extension, ready to be registered with a manga source manager.
 *
 * @param pkg         the APK's declared package name.
 * @param versionName the full versionName string from the APK manifest.
 * @param versionCode the APK's versionCode (longVersionCode on API 28+, versionCode below).
 * @param libVersion  the derived extensions-lib version (major.minor from [libVersionOf]).
 * @param nsfw        true when the extension is flagged for adult content.
 * @param sources     the [Source] instances produced by this extension.
 */
data class MihonLoadedExtension(
    val pkg: String,
    val versionName: String,
    val versionCode: Long,
    val libVersion: Double,
    val nsfw: Boolean,
    val sources: List<Source>,
    val iconBase64: String? = null,
)

/**
 * Loads Mihon manga-extension APKs via [DexClassLoader].
 *
 * A loaded extension must:
 *  1. Declare `<uses-feature android:name="tachiyomi.extension">` in its manifest.
 *  2. Declare its source class(es) in metadata key [METADATA_CLASS] (semicolon-separated).
 *  3. Have a [libVersionOf] result in the exact supported extension ABI set (1.4 or 1.6).
 *  4. Match the repository-published SHA-256 signer fingerprint and expected package name.
 *
 * This loader is isolated from RAVEN23's video/anime provider pipeline. Manga extension
 * APKs are third-party executable code, so only explicitly confirmed installs from a trusted
 * repository are loaded and every APK is checked before its DEX is made executable.
 *
 * The loader never throws — all errors are wrapped as [Result.failure].
 */
private fun encodeExtensionIcon(
    appInfo: ApplicationInfo,
    packageManager: PackageManager,
): String? = runCatching {
    val drawable = appInfo.loadIcon(packageManager)
    val size = 96
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val oldBounds = Rect(drawable.bounds)
    try {
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        ByteArrayOutputStream().use { output ->
            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
            Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
        }
    } finally {
        drawable.bounds = oldBounds
        bitmap.recycle()
    }
}.getOrNull()

object MihonExtensionLoader {

    /**
     * The vendored source API is pinned to the Mihon/Tachiyomi extension interfaces
     * ported from the supplied Zangetsu integration. Keep this an exact allow-list:
     * silently accepting an unknown ABI can load classes that link against methods
     * absent from the host and crash during extension construction or source calls.
     *
     * Mihon v0.21.3 is the last stable release supporting both legacy 1.4 and 1.6
     * extension libraries. Newer ABI versions must be added only after their source
     * interfaces and required host services have been ported and verified.
     */
    private val SUPPORTED_LIB_VERSIONS = setOf(1.4, 1.6)

    // PackageManager exposes Android manifest float metadata as Float.
    // A literal 1.6f therefore widens to 1.600000023841858 as a Double.
    // Accept only the exact Double constants or their exact Float-widened forms;
    // do not use a numeric tolerance that could admit another ABI version.

    /** Manifest feature flag that identifies a valid Mihon manga extension. */
    private const val FEATURE = "tachiyomi.extension"

    /** Manifest metadata key listing the source class(es), semicolon-separated. */
    private const val METADATA_CLASS = "tachiyomi.extension.class"

    /** Manifest metadata key for the NSFW flag. Mihon uses a single-n key (no fork variant). */
    private const val METADATA_NSFW = "tachiyomi.extension.nsfw"

    /** Optional explicit extension ABI override used by Mihon before version-name fallback. */
    private const val METADATA_LIB_VERSION = "tachiyomix.extensionLib"

    /**
     * Derives the extensions-lib version from the APK [versionName].
     *
     * The versionName encodes the lib version as everything before the last dot. Examples:
     *   "1.4.52" → substringBeforeLast('.') = "1.4" → 1.4
     *   "1.6.11" → substringBeforeLast('.') = "1.6" → 1.6
     *
     * @param versionName the full versionName string from the APK manifest.
     * @return the derived lib version as a Double.
     * @throws NumberFormatException if the result is not parseable as a Double.
     */
    fun libVersionOf(versionName: String): Double =
        versionName.substringBeforeLast('.').toDouble()

    /**
     * Resolves an extension class name, prefixing leading-dot names with the package name.
     *
     * @param pkg the APK package name (e.g. "eu.kanade.tachiyomi.extension.en.mangadex").
     * @param raw the raw class name from the manifest metadata (e.g. ".MangaDex" or fully-qualified).
     * @return the fully-qualified class name.
     */
    fun resolveClassName(pkg: String, raw: String): String =
        if (raw.startsWith(".")) pkg + raw else raw

    /**
     * Returns true only for an extension ABI implemented by the vendored host API.
     */
    internal fun normalizeSupportedLibVersion(libVersion: Double): Double? {
        if (!libVersion.isFinite()) return null
        return SUPPORTED_LIB_VERSIONS.firstOrNull { supported ->
            libVersion == supported || libVersion == supported.toFloat().toDouble()
        }
    }

    fun isLibVersionSupported(libVersion: Double): Boolean =
        normalizeSupportedLibVersion(libVersion) != null

    /** SHA-256 certificate fingerprint(s), in lowercase hex without separators. */
    @Suppress("DEPRECATION")
    private fun signingFingerprints(pkgInfo: android.content.pm.PackageInfo): Set<String> {
        val signatures: Array<Signature> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = pkgInfo.signingInfo ?: return emptySet()
            if (signingInfo.hasMultipleSigners()) signingInfo.apkContentsSigners
            else signingInfo.signingCertificateHistory
        } else {
            pkgInfo.signatures ?: emptyArray()
        }
        return signatures.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
                .joinToString("") { byte -> "%02x".format(byte) }
        }.toSet()
    }

    private fun normalizeFingerprint(value: String): String =
        value.lowercase().filter { it in '0'..'9' || it in 'a'..'f' }

    /**
     * Loads a Mihon manga-extension APK, reads its manifest metadata, gates the
     * extensions-lib version, and instantiates the [Source](s) it declares.
     *
     * Must be called on any thread (the DexClassLoader optimisation and class initialisation
     * can be slow — do not call on the main thread).
     *
     * @param context Android context used for [PackageManager], [DexClassLoader] cache dir,
     *                and the lazy RAVEN23 Mihon dependency graph.
     * @param apkFile the extension APK file on disk.
     * @param expectedSigningKey SHA-256 certificate fingerprint published by its repository.
     * @param expectedPackageName package name declared by that repository entry.
     * @return [Result.success] containing a [MihonLoadedExtension], or [Result.failure] on any
     *         error. This method never throws.
     */
    @Suppress("DEPRECATION")
    fun load(
        context: Context,
        apkFile: File,
        expectedSigningKey: String,
        expectedPackageName: String = apkFile.nameWithoutExtension,
    ): Result<MihonLoadedExtension> = runCatching {
        RavenMihonInjektModules.ensureRegistered(context)

        require(apkFile.isFile && apkFile.length() > 4096L) { "Extension APK is missing or truncated" }
        val normalizedSigningKey = expectedSigningKey.trim().replace(":", "")
        val expected = normalizeFingerprint(normalizedSigningKey)
        require(expected.length == 64 && normalizedSigningKey.matches(Regex("(?i)^[0-9a-f]{64}$"))) {
            "Repository signing fingerprint is missing or invalid"
        }
        require(expectedPackageName.matches(Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$"))) {
            "Expected extension package name is invalid"
        }

        val pm = context.packageManager
        val signatureFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION") PackageManager.GET_SIGNATURES
        }
        val flags = PackageManager.GET_META_DATA or PackageManager.GET_CONFIGURATIONS or signatureFlag
        val pkgInfo = pm.getPackageArchiveInfo(apkFile.absolutePath, flags)
            ?: error("Not an APK or could not parse manifest: ${apkFile.name}")
        require(pkgInfo.packageName == expectedPackageName) {
            "Extension package mismatch: expected $expectedPackageName, found ${pkgInfo.packageName}"
        }
        val actualFingerprints = signingFingerprints(pkgInfo)
        require(expected in actualFingerprints) {
            "Extension signer does not match the trusted repository fingerprint"
        }

        // Verify the uses-feature flag that identifies a Mihon manga extension.
        val hasFeature = pkgInfo.reqFeatures?.any { it.name == FEATURE } == true
        require(hasFeature) {
            "Not a Mihon manga extension (missing <uses-feature name=\"$FEATURE\">)"
        }

        val appInfo = pkgInfo.applicationInfo
            ?: error("Missing applicationInfo in APK manifest: ${apkFile.name}")

        // Set the source path so PackageManager can read resources from this APK.
        appInfo.sourceDir = apkFile.absolutePath
        appInfo.publicSourceDir = apkFile.absolutePath
        // Extract a small package icon for the Mihon source picker. Icon failure
        // must never prevent an otherwise trusted extension from loading.
        val iconBase64 = encodeExtensionIcon(appInfo, pm)

        val versionName = pkgInfo.versionName
            ?: error("Missing versionName in APK manifest: ${apkFile.name}")

        val versionCode: Long =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkgInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                pkgInfo.versionCode.toLong()
            }

        val explicitLibVersion = appInfo.metaData
            ?.getFloat(METADATA_LIB_VERSION, 0f)
            ?.takeIf { it != 0f }
        val rawLibVersion = explicitLibVersion?.toDouble() ?: runCatching {
            libVersionOf(versionName)
        }.getOrElse { e ->
            error("Cannot parse lib version from versionName \"$versionName\": ${e.message}")
        }
        // Normalize Android's Float widening artifact before storing/comparing
        // the ABI. 1.6f otherwise arrives as 1.600000023841858 and was rejected
        // by the previous exact Double comparison despite being supported.
        val libVersion = normalizeSupportedLibVersion(rawLibVersion)
            ?: error("Unsupported extensions-lib version $rawLibVersion (supported: 1.4, 1.6)")

        val meta = appInfo.metaData
        val classList = meta?.getString(METADATA_CLASS).orEmpty().trim()
        require(classList.isNotBlank()) {
            "No source classes declared (missing metadata key \"$METADATA_CLASS\")"
        }

        val nsfw = meta?.getInt(METADATA_NSFW, 0) == 1

        val pkg = appInfo.packageName

        // Optimised DEX output directory, scoped to the Mihon namespace. Kept separate from
        // "aniyomi-dex" — sharing risks cross-contaminating optimised DEX for identically-named
        // classes between the two extension ecosystems.
        val optimizedDir = File(context.codeCacheDir, "mihon-dex").apply { mkdirs() }

        // Android's runtime (W^X protection) refuses to load a DEX/APK that is
        // still writable by the app ("Writable dex file is not allowed"). The apk
        // was just downloaded into app-private storage, so strip write access
        // before handing it to the classloader.
        apkFile.setReadOnly()

        val loader = DexClassLoader(
            apkFile.absolutePath,
            optimizedDir.absolutePath,
            null,                    // librarySearchPath — extensions have no native libs
            context.classLoader,     // parent classloader so vendored runtime is accessible
        )

        val sources = classList
            .split(";")
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .flatMap { raw ->
                val className = resolveClassName(pkg, raw)
                val clazz = loader.loadClass(className)
                val instance = clazz.getDeclaredConstructor().newInstance()
                when (instance) {
                    is Source -> listOf(instance)
                    is SourceFactory -> instance.createSources()
                    else -> emptyList()
                }
            }

        require(sources.isNotEmpty()) {
            "Extension produced no Source instances from class list: $classList"
        }

        MihonLoadedExtension(
            pkg = pkg,
            versionName = versionName,
            versionCode = versionCode,
            libVersion = libVersion,
            nsfw = nsfw,
            sources = sources,
            iconBase64 = iconBase64,
        )
    }
}
