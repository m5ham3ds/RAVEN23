package com.m5ham3ds.raven23

import android.content.Context
import android.graphics.Rect
import android.net.Uri
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.tasks.Task
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.Locale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Android implementation of the RAVEN23 manga-page OCR/offline translation channel. */
internal class MangaTranslationBridge(context: Context) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in SUPPORTED_METHODS) {
            result.notImplemented()
            return
        }
        scope.launch {
            try {
                val value = execute(call)
                withContext(Dispatchers.Main) { result.success(value) }
            } catch (error: Throwable) {
                if (error is CancellationException) throw error
                val code = when (error) {
                    is IllegalArgumentException -> "invalid_argument"
                    is IOException -> "image_read_failed"
                    else -> "manga_translation_failed"
                }
                withContext(Dispatchers.Main) {
                    result.error(code, error.message ?: "Manga translation failed.", null)
                }
            }
        }
    }

    fun dispose() {
        scope.cancel()
    }

    private suspend fun execute(call: MethodCall): Any? = when (call.method) {
        "supportedOcrLanguages" -> OCR_LANGUAGES.sorted()
        "supportedOfflineLanguages" -> TranslateLanguage.getAllLanguages().mapNotNull(::canonicalCode).distinct().sorted()
        "modelStatus" -> readModelStatus(
            requiredString(call, "sourceLanguage"),
            requiredString(call, "targetLanguage"),
            requiredString(call, "engine"),
        )
        "downloadModels" -> downloadRequiredModels(
            requiredString(call, "sourceLanguage"),
            requiredString(call, "targetLanguage"),
            requiredString(call, "engine"),
        )
        "recognize" -> recognizePage(
            requiredString(call, "filePath"),
            requiredString(call, "sourceLanguage"),
        )
        "translateTexts" -> translateTextBatch(
            requiredStringList(call, "texts"),
            requiredString(call, "sourceLanguage"),
            requiredString(call, "targetLanguage"),
        )
        else -> null
    }

    private suspend fun readModelStatus(source: String, target: String, engine: String): Map<String, Boolean> {
        requireEngine(engine)
        val ocrReady = isOcrRecognizerAvailable(source)
        if (engine == ONLINE) {
            return mapOf(
                "ocrReady" to ocrReady,
                "sourceModelReady" to true,
                "targetModelReady" to true,
            )
        }
        val sourceCode = mlKitLanguage(source)
        val targetCode = mlKitLanguage(target)
        val downloaded = getDownloadedLanguageModels()
        return mapOf(
            "ocrReady" to ocrReady,
            "sourceModelReady" to (sourceCode == targetCode || sourceCode in downloaded),
            "targetModelReady" to (sourceCode == targetCode || targetCode in downloaded),
        )
    }

    /** Called only after the reader explicitly asks to download missing models. */
    private suspend fun downloadRequiredModels(source: String, target: String, engine: String) {
        requireEngine(engine)
        installOcrRecognizer(source)
        if (engine == ONLINE) return

        val sourceCode = mlKitLanguage(source)
        val targetCode = mlKitLanguage(target)
        if (sourceCode == targetCode) return
        val manager = RemoteModelManager.getInstance()
        val alreadyDownloaded = getDownloadedLanguageModels()
        val conditions = DownloadConditions.Builder().build()
        for (code in listOf(sourceCode, targetCode).distinct()) {
            if (code in alreadyDownloaded) continue
            val remoteModel = TranslateRemoteModel.Builder(code).build()
            manager.download(remoteModel, conditions).awaitResult()
        }
    }

    private suspend fun isOcrRecognizerAvailable(language: String): Boolean {
        checkPlayServices()
        val recognizer = recognizerFor(language)
        return try {
            ModuleInstall.getClient(appContext)
                .areModulesAvailable(recognizer)
                .awaitResult()
                .areModulesAvailable()
        } finally {
            recognizer.close()
        }
    }

    private suspend fun installOcrRecognizer(language: String) {
        checkPlayServices()
        val recognizer = recognizerFor(language)
        try {
            val installer = ModuleInstall.getClient(appContext)
            if (installer.areModulesAvailable(recognizer).awaitResult().areModulesAvailable()) return
            val request = ModuleInstallRequest.newBuilder().addApi(recognizer).build()
            val installResult = installer.installModules(request).awaitResult()
            if (installResult.areModulesAlreadyInstalled()) return
            // Module installation is asynchronous; wait for the recognizer API to report ready.
            repeat(OCR_INSTALL_POLLS) {
                kotlinx.coroutines.delay(OCR_INSTALL_INTERVAL_MS)
                if (installer.areModulesAvailable(recognizer).awaitResult().areModulesAvailable()) return
            }
            throw IllegalStateException("The on-device OCR module did not finish installing.")
        } finally {
            recognizer.close()
        }
    }

    private suspend fun recognizePage(filePath: String, language: String): Map<String, Any> {
        checkPlayServices()
        val imageFile = File(filePath)
        require(imageFile.isFile && imageFile.canRead()) { "The selected manga page is not readable." }
        val recognizer = recognizerFor(language)
        try {
            val input = InputImage.fromFilePath(appContext, Uri.fromFile(imageFile))
            val recognized = recognizer.process(input).awaitResult()
            val rotated = input.rotationDegrees == 90 || input.rotationDegrees == 270
            val imageWidth = if (rotated) input.height else input.width
            val imageHeight = if (rotated) input.width else input.height
            require(imageWidth > 0 && imageHeight > 0) { "The manga page has invalid image dimensions." }

            val regions = recognized.textBlocks.mapNotNull { block ->
                val box = block.boundingBox ?: return@mapNotNull null
                if (block.text.isBlank()) return@mapNotNull null
                normalizedRegion(block.text, box, imageWidth, imageHeight)
            }
            return mapOf(
                "imageWidth" to imageWidth,
                "imageHeight" to imageHeight,
                "regions" to regions,
            )
        } finally {
            recognizer.close()
        }
    }

    private suspend fun translateTextBatch(texts: List<String>, source: String, target: String): List<String> {
        val sourceCode = mlKitLanguage(source)
        val targetCode = mlKitLanguage(target)
        if (texts.isEmpty() || sourceCode == targetCode) return texts
        val available = getDownloadedLanguageModels()
        require(sourceCode in available && targetCode in available) {
            "The required offline language models have not been downloaded yet."
        }

        val translator: Translator = Translation.getClient(
            TranslatorOptions.Builder()
                .setSourceLanguage(sourceCode)
                .setTargetLanguage(targetCode)
                .build(),
        )
        try {
            val output = ArrayList<String>(texts.size)
            for (text in texts) output += translator.translate(text).awaitResult()
            return output
        } finally {
            translator.close()
        }
    }

    private suspend fun getDownloadedLanguageModels(): Set<String> =
        RemoteModelManager.getInstance()
            .getDownloadedModels(TranslateRemoteModel::class.java)
            .awaitResult()
            .mapNotNull { canonicalCode(it.language) }
            .toSet()

    private fun recognizerFor(language: String): TextRecognizer {
        val code = normalizeLanguage(language)
        return when (code) {
            "zh" -> TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            "ja" -> TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
            "ko" -> TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
            "hi" -> TextRecognition.getClient(DevanagariTextRecognizerOptions.Builder().build())
            "en", "es", "fr", "de", "pt", "it" -> TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            else -> throw IllegalArgumentException("OCR does not support the source language '$language'.")
        }
    }

    private fun mlKitLanguage(language: String): String {
        val normalized = canonicalCode(language)
        return normalized?.let(TranslateLanguage::fromLanguageTag)
            ?: throw IllegalArgumentException("Offline translation does not support '$language'.")
    }

    private fun canonicalCode(language: String): String? {
        val tag = language.trim().replace('_', '-')
        if (tag.isEmpty()) return null
        val root = Locale.forLanguageTag(tag).language.lowercase(Locale.ROOT)
        return if (root.isEmpty()) null else TranslateLanguage.fromLanguageTag(root)?.lowercase(Locale.ROOT)
    }

    private fun normalizeLanguage(language: String): String =
        language.trim().replace('_', '-').substringBefore('-').lowercase(Locale.ROOT)

    private fun normalizedRegion(text: String, box: Rect, width: Int, height: Int): Map<String, Any> {
        val left = (box.left.toDouble() / width).coerceIn(0.0, 1.0)
        val top = (box.top.toDouble() / height).coerceIn(0.0, 1.0)
        val right = (box.right.toDouble() / width).coerceIn(left, 1.0)
        val bottom = (box.bottom.toDouble() / height).coerceIn(top, 1.0)
        return mapOf("text" to text, "left" to left, "top" to top, "right" to right, "bottom" to bottom)
    }

    private fun checkPlayServices() {
        val code = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(appContext)
        check(code == ConnectionResult.SUCCESS) {
            "Google Play services is required for on-device manga OCR and translation."
        }
    }

    private fun requireEngine(engine: String) {
        require(engine == ONLINE || engine == OFFLINE) { "Unknown manga translation engine '$engine'." }
    }

    private fun requiredString(call: MethodCall, name: String): String =
        call.argument<String>(name)?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("Missing '$name'.")

    private fun requiredStringList(call: MethodCall, name: String): List<String> {
        val values = call.argument<List<*>>(name)
            ?: throw IllegalArgumentException("Missing '$name'.")
        require(values.all { it is String }) { "Every '$name' item must be text." }
        return values.filterIsInstance<String>()
    }

    private companion object {
        const val ONLINE = "online"
        const val OFFLINE = "offline"
        const val OCR_INSTALL_POLLS = 120
        const val OCR_INSTALL_INTERVAL_MS = 1000L
        val OCR_LANGUAGES = setOf("ja", "zh", "ko", "en", "es", "fr", "de", "pt", "it", "hi")
        val SUPPORTED_METHODS = setOf(
            "supportedOcrLanguages",
            "supportedOfflineLanguages",
            "modelStatus",
            "downloadModels",
            "recognize",
            "translateTexts",
        )
    }
}

private suspend fun <T> Task<T>.awaitResult(): T = suspendCancellableCoroutine { continuation ->
    addOnCompleteListener { task ->
        if (!continuation.isActive) return@addOnCompleteListener
        if (task.isSuccessful) {
            continuation.resume(task.result)
        } else {
            continuation.resumeWithException(
                task.exception ?: IllegalStateException("Google Play task did not complete successfully."),
            )
        }
    }
}
