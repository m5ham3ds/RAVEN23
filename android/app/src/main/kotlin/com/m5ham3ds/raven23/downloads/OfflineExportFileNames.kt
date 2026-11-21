package com.m5ham3ds.raven23.downloads

/**
 * Pure naming rules shared by the Android export bridge and its unit tests.
 * Kept independent of Activity and MediaStore so filename contracts can be
 * verified on the JVM.
 */
internal object OfflineExportFileNames {
    private val unsafePathCharacters = Regex("""[\\/:*?"<>|\p{Cntrl}]""")
    private val repeatedWhitespace = Regex("\\s+")
    private val episodePrefix = Regex("(?i)^\\s*S\\d+\\s*[•·|:/-]?\\s*E\\d+\\s*")

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

        // Provider labels commonly look like "S02 • E07 The Name • From Server".
        // Strip only the episode-code prefix and trailing provider attribution.
        // Do not split on the first bullet: that would discard "E07 The Name".
        val label = episodeLabel
            .substringBefore(" • From ", missingDelimiterValue = episodeLabel)
            .substringBefore(" • Server ", missingDelimiterValue = episodeLabel)
            .trim()
            .replace(episodePrefix, "")
            .trim()
            .takeIf { it.isNotEmpty() && !it.startsWith("From ", ignoreCase = true) }

        return listOf(title, seasonEpisode, label)
            .filterNotNull()
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(" - ")
    }

    internal fun sanitize(value: String): String =
        value.trim()
            .replace(unsafePathCharacters, "_")
            .replace(repeatedWhitespace, " ")
            .trim(' ', '.')
            .take(120)
            .ifBlank { "RAVEN23 video" }
}
