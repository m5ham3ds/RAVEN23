package com.m5ham3ds.raven23.downloads

/**
 * Pure naming rules shared by the Android export bridge and its unit tests.
 * Kept independent of Activity and MediaStore so filename contracts can be
 * verified on the JVM.
 */
internal object OfflineExportFileNames {
    internal fun buildStem(
        title: String,
        isMovie: Boolean,
        season: Int,
        episode: Int,
        episodeLabel: String = "",
    ): String {
        val seasonEpisode = if (season >= 0 && episode >= 0) {
            "S${season.toString().padStart(2, '0')}E${episode.toString().padStart(2, '0')}"
        } else {
            ""
        }
        if (isMovie || seasonEpisode.isEmpty()) return title
        val label = episodeLabel
            .substringAfter(" • ", "")
            .substringBefore(" • ")
            .trim()
            .takeIf { it.isNotEmpty() && !it.startsWith("From ", true) }
        return listOf(title, seasonEpisode, label)
            .filterNotNull()
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(" - ")
    }
    
    internal fun sanitize(value: String): String =
        value.trim()
            .replace(Regex("[\\\\/:*?\\\"<>|\\\\p{Cntrl}]"), "_")
            .replace(Regex("\\\\s+"), " ")
            .trim(' ', '.')
            .take(120)
            .ifBlank { "RAVEN23 video" }
    
    
}
