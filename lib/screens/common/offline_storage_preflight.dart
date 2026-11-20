import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/offline_download_provider.dart';
import '../../services/offline_download_service.dart';

abstract final class OfflineStoragePreflight {
  static Future<bool> ensureAvailable(
    BuildContext context, {
    required int? estimatedDownloadBytes,
    bool isResume = false,
  }) async {
    final provider = context.read<OfflineDownloadProvider>();
    OfflineStorageSnapshot snapshot;
    try {
      snapshot = await provider.getStorageSnapshot();
    } catch (_) {
      // Android repeats the authoritative check immediately before enqueue/resume.
      return true;
    }
    if (snapshot.hasRoomFor(estimatedDownloadBytes)) return true;
    if (!context.mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            var checking = false;
            String? checkError;
            return StatefulBuilder(
              builder: (context, setState) {
                String formatBytes(int value) {
                  if (value < 1024) return '$value B';
                  final kb = value / 1024;
                  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
                  final mb = kb / 1024;
                  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
                  return '${(mb / 1024).toStringAsFixed(2)} GB';
                }

                final requiredBytes =
                    OfflineStorageSnapshot.minimumReserveBytes +
                    (estimatedDownloadBytes != null && estimatedDownloadBytes > 0
                        ? estimatedDownloadBytes
                        : 0);
                return AlertDialog(
                  title: const Text('Not enough storage'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estimatedDownloadBytes != null && estimatedDownloadBytes > 0
                            ? '${isResume ? 'Estimated remaining size' : 'Estimated video size'}: ~${formatBytes(estimatedDownloadBytes)}'
                            : 'Video size: unavailable from this source',
                      ),
                      const SizedBox(height: 8),
                      Text('Available now: ${formatBytes(snapshot.availableBytes)}'),
                      Text('Required with safety reserve: ${formatBytes(requiredBytes)}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Free up space, then recheck. The download will not start or resume until enough room is available.',
                      ),
                      if (checkError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          checkError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: checking
                          ? null
                          : () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: checking
                          ? null
                          : () async {
                              setState(() {
                                checking = true;
                                checkError = null;
                              });
                              try {
                                final next = await provider.getStorageSnapshot();
                                if (!context.mounted) return;
                                if (next.hasRoomFor(estimatedDownloadBytes)) {
                                  Navigator.pop(dialogContext, true);
                                  return;
                                }
                                setState(() {
                                  snapshot = next;
                                  checking = false;
                                });
                              } catch (_) {
                                if (!context.mounted) return;
                                setState(() {
                                  checkError = 'Could not recheck storage. Please try again.';
                                  checking = false;
                                });
                              }
                            },
                      child: checking
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Recheck storage'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }
}
