import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/live_tv_service_manager.dart';

/// Small shared Mobile/TV surface for managing user-provided IPTV playlists.
Future<bool> showIptvPlaylistManagerDialog(
  BuildContext context,
  LiveTvServiceManager manager,
) async {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  var playlists = await manager.m3uPlaylists();
  if (!context.mounted) return false;
  final urlController = TextEditingController();
  final nameController = TextEditingController();
  var changed = false;
  var busy = false;
  String? error;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> addRemote() async {
          final url = urlController.text.trim();
          if (url.isEmpty) {
            setDialogState(
              () => error = isArabic
                  ? 'أدخل رابط قائمة M3U أولاً.'
                  : 'Enter an M3U playlist URL first.',
            );
            return;
          }
          setDialogState(() {
            busy = true;
            error = null;
          });
          try {
            await manager.addM3uPlaylistUrl(
              url: url,
              name: nameController.text.trim().isEmpty
                  ? null
                  : nameController.text.trim(),
            );
            playlists = await manager.m3uPlaylists();
            urlController.clear();
            nameController.clear();
            changed = true;
            setDialogState(() {});
          } catch (exception) {
            setDialogState(() => error = _safeError(exception, isArabic));
          } finally {
            setDialogState(() => busy = false);
          }
        }

        Future<void> importLocal() async {
          setDialogState(() {
            busy = true;
            error = null;
          });
          try {
            final picked = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const <String>['m3u', 'm3u8', 'txt'],
              withData: true,
              allowMultiple: false,
            );
            if (picked == null || picked.files.isEmpty) return;
            final file = picked.files.single;
            final Uint8List? suppliedBytes = file.bytes;
            final Uint8List bytes;
            if (suppliedBytes != null && suppliedBytes.isNotEmpty) {
              bytes = suppliedBytes;
            } else if (file.path != null) {
              bytes = await File(file.path!).readAsBytes();
            } else {
              throw const FormatException(
                'The selected playlist file is empty or unreadable.',
              );
            }
            await manager.addLocalM3uPlaylist(
              filename: file.name,
              bytes: bytes,
              name: nameController.text.trim().isEmpty
                  ? null
                  : nameController.text.trim(),
            );
            playlists = await manager.m3uPlaylists();
            nameController.clear();
            changed = true;
            setDialogState(() {});
          } catch (exception) {
            setDialogState(() => error = _safeError(exception, isArabic));
          } finally {
            setDialogState(() => busy = false);
          }
        }

        Future<void> remove(String id) async {
          setDialogState(() {
            busy = true;
            error = null;
          });
          try {
            await manager.removeM3uPlaylist(id);
            playlists = await manager.m3uPlaylists();
            changed = true;
            setDialogState(() {});
          } catch (exception) {
            setDialogState(() => error = _safeError(exception, isArabic));
          } finally {
            setDialogState(() => busy = false);
          }
        }

        return AlertDialog(
          title: Text(isArabic ? 'إدارة قوائم IPTV' : 'Manage IPTV playlists'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    isArabic
                        ? 'أضف قائمة M3U من رابط عام أو استورد ملفاً من جهازك. تُحفظ الملفات المستوردة داخل مساحة التطبيق الخاصة.'
                        : 'Add an M3U playlist from a public URL or import a file from your device. Imported files are copied into app-private storage.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: isArabic
                          ? 'اسم القائمة (اختياري)'
                          : 'Playlist name (optional)',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: isArabic
                          ? 'رابط M3U / M3U8'
                          : 'M3U / M3U8 URL',
                      hintText: 'https://example.com/playlist.m3u',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: busy ? null : addRemote,
                    icon: const Icon(Icons.add_link),
                    label: Text(isArabic ? 'إضافة الرابط' : 'Add URL'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : importLocal,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      isArabic ? 'استيراد ملف من الجهاز' : 'Import local file',
                    ),
                  ),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  Text(
                    isArabic
                        ? 'القوائم المضافة (${playlists.length}/8)'
                        : 'Added playlists (${playlists.length}/8)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (playlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        isArabic
                            ? 'لم تتم إضافة أي قوائم بعد.'
                            : 'No playlists have been added yet.',
                      ),
                    )
                  else
                    for (final playlist in playlists)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          playlist.isLocal
                              ? Icons.folder_copy_outlined
                              : Icons.cloud_outlined,
                        ),
                        title: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          playlist.isLocal
                              ? (isArabic
                                    ? 'ملف محلي مستورد'
                                    : 'Imported local file')
                              : playlist.url ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: isArabic ? 'حذف' : 'Remove',
                          onPressed: busy ? null : () => remove(playlist.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.of(dialogContext).pop(changed),
              child: Text(isArabic ? 'إغلاق' : 'Close'),
            ),
          ],
        );
      },
    ),
  );
  urlController.dispose();
  nameController.dispose();
  return result ?? changed;
}

String _safeError(Object error, bool isArabic) {
  if (error is FormatException) {
    return error.message.toString();
  }
  if (isArabic) {
    return 'تعذرت إضافة القائمة. تحقق من الرابط أو الملف وحاول مجدداً.';
  }
  return 'The playlist could not be added. Check the URL or file and try again.';
}
