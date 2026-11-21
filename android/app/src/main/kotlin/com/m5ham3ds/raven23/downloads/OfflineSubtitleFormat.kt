package com.m5ham3ds.raven23.downloads

import java.util.Locale

/**
 * Preserves the user's selected sidecar format when an external subtitle was
 * normalized to WebVTT for playback. This keeps the public DCIM copy in the
 * original SRT format when SRT was selected.
 */
internal object OfflineSubtitleFormat {
    fun extension(requestedFormat: String?, sourceUrl: String): String {
        val format = requestedFormat.orEmpty()
            .trim()
            .lowercase(Locale.ROOT)
            .removePrefix(".")
        if (format.contains("srt") || format.contains("subrip")) return "srt"
        if (format.contains("vtt") || format.contains("webvtt")) return "vtt"

        val sourcePath = sourceUrl
            .substringBefore('?')
            .substringBefore('#')
            .lowercase(Locale.ROOT)
        if (sourcePath.endsWith(".srt")) return "srt"
        return "vtt"
    }

    fun webVttToSrt(content: String): String {
        val normalized = content
            .removePrefix("\uFEFF")
            .replace("\r\n", "\n")
            .replace('\r', '\n')
        require(normalized.trimStart().startsWith("WEBVTT", ignoreCase = true)) {
            "Selected SRT subtitle content is not valid WebVTT."
        }

        val body = normalized.substringAfter('\n', "")
        val blocks = body.split(Regex("\n[ \t]*\n"))
        val timePattern = Regex(
            """^(?:(\d{2}):)?(\d{2}):(\d{2})\.(\d{3})\s*-->\s*(?:(\d{2}):)?(\d{2}):(\d{2})\.(\d{3})(?:\s+.*)?$""",
        )
        val cues = mutableListOf<String>()

        for (block in blocks) {
            val lines = block.lines()
            val timingIndex = lines.indexOfFirst { it.contains("-->") }
            if (timingIndex < 0) continue
            val timing = timePattern.matchEntire(lines[timingIndex].trim()) ?: continue
            val text = lines.drop(timingIndex + 1).joinToString("\n").trim()
            if (text.isEmpty()) continue

            val start = (timing.groupValues[1].ifEmpty { "00" }) + ":" +
                timing.groupValues[2] + ":" + timing.groupValues[3] + "," +
                timing.groupValues[4]
            val end = (timing.groupValues[5].ifEmpty { "00" }) + ":" +
                timing.groupValues[6] + ":" + timing.groupValues[7] + "," +
                timing.groupValues[8]
            cues += (cues.size + 1).toString() + "\n" +
                start + " --> " + end + "\n" + text
        }

        require(cues.isNotEmpty()) { "Selected subtitle contains no valid WebVTT cues." }
        return cues.joinToString("\n\n", postfix = "\n")
    }
}
