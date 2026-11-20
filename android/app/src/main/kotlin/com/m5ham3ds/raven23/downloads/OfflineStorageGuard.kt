package com.m5ham3ds.raven23.downloads

/** Keep at least 200 MiB free for Android, app databases and temporary writes. */
internal const val OFFLINE_STORAGE_RESERVE_BYTES = 200L * 1024L * 1024L
internal const val STORAGE_LOW_STOP_REASON = 2

internal fun requiredFreeBytes(
    estimatedDownloadBytes: Long?,
    reserveBytes: Long = OFFLINE_STORAGE_RESERVE_BYTES,
): Long = (estimatedDownloadBytes ?: 0L).coerceAtLeast(0L) + reserveBytes

internal fun hasEnoughStorageToStart(
    availableBytes: Long,
    estimatedDownloadBytes: Long?,
    reserveBytes: Long = OFFLINE_STORAGE_RESERVE_BYTES,
): Boolean = availableBytes > requiredFreeBytes(estimatedDownloadBytes, reserveBytes)

internal fun shouldPauseForLowStorage(
    availableBytes: Long,
    reserveBytes: Long = OFFLINE_STORAGE_RESERVE_BYTES,
): Boolean = availableBytes <= reserveBytes

internal fun hasEnoughStorageToResume(
    availableBytes: Long,
    estimatedDownloadBytes: Long?,
    bytesAlreadyDownloaded: Long,
    reserveBytes: Long = OFFLINE_STORAGE_RESERVE_BYTES,
): Boolean {
    val remainingEstimate = estimatedDownloadBytes
        ?.let { (it - bytesAlreadyDownloaded.coerceAtLeast(0L)).coerceAtLeast(0L) }
    return hasEnoughStorageToStart(availableBytes, remainingEstimate, reserveBytes)
}
