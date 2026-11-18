import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../mihon/mihon_runtime.dart';

/// Offline chapter cache backed by app-private storage. Mihon remains the only
/// network transport; downloaded image bytes are written after the source's own
/// HTTP client has applied its cookies, headers and Cloudflare session.
class MangaChapterDownloadStore {
  MangaChapterDownloadStore._();

  static final MangaChapterDownloadStore instance =
      MangaChapterDownloadStore._();

  Future<Directory> _workDirectory(int anilistId, int sourceId) async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/manga_offline/$anilistId/$sourceId');
  }

  String _chapterKey(String chapterUrl) =>
      sha256.convert(utf8.encode(chapterUrl)).toString();

  Future<Directory> _chapterDirectory(
    int anilistId,
    int sourceId,
    String chapterUrl,
  ) async {
    final parent = await _workDirectory(anilistId, sourceId);
    return Directory('${parent.path}/${_chapterKey(chapterUrl)}');
  }

  Future<List<Map<String, dynamic>>?> cachedPages({
    required int anilistId,
    required int sourceId,
    required String chapterUrl,
  }) async {
    final directory = await _chapterDirectory(anilistId, sourceId, chapterUrl);
    final backup = Directory('${directory.path}.previous');
    if (!await directory.exists() && await backup.exists()) {
      await backup.rename(directory.path);
    } else if (await directory.exists() && await backup.exists()) {
      await backup.delete(recursive: true);
    }
    final manifestFile = File('${directory.path}/manifest.json');
    if (!await manifestFile.exists()) return null;
    try {
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map || decoded['pages'] is! List) return null;
      final pages = <Map<String, dynamic>>[];
      for (final raw in decoded['pages'] as List) {
        if (raw is! Map) return null;
        final item = Map<String, dynamic>.from(raw);
        final filename = '${item['file'] ?? ''}';
        if (!RegExp(r'^\d{4}\.page$').hasMatch(filename)) return null;
        final file = File('${directory.path}/$filename');
        if (!await file.exists() || await file.length() == 0) return null;
        pages.add(<String, dynamic>{
          'imageUrl': item['imageUrl'],
          'headers': item['headers'] is Map
              ? item['headers']
              : const <String, String>{},
          'localPath': file.path,
          'index': item['index'],
        });
      }
      return pages.isEmpty ? null : pages;
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> downloadedChapterUrls({
    required int anilistId,
    required int sourceId,
  }) async {
    final parent = await _workDirectory(anilistId, sourceId);
    if (!await parent.exists()) return <String>{};
    final result = <String>{};
    await for (final entity in parent.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final manifest = File('${entity.path}/manifest.json');
      if (!await manifest.exists()) continue;
      try {
        final decoded = jsonDecode(await manifest.readAsString());
        if (decoded is! Map || decoded['chapterUrl'] is! String) continue;
        final pages = await cachedPages(
          anilistId: anilistId,
          sourceId: sourceId,
          chapterUrl: decoded['chapterUrl'] as String,
        );
        if (pages != null) result.add(decoded['chapterUrl'] as String);
      } catch (_) {
        // Ignore incomplete or corrupt manifests; they are not offline-ready.
      }
    }
    return result;
  }

  Future<void> downloadChapter({
    required int anilistId,
    required String workTitle,
    required MihonSourceInfo source,
    required String chapterUrl,
    required String chapterTitle,
    required MihonRuntimeService runtime,
    void Function(int completed, int total)? onProgress,
  }) async {
    final onlinePages = await runtime.pages(source.id, chapterUrl);
    final pages = onlinePages
        .where((page) => '${page['imageUrl'] ?? ''}'.trim().isNotEmpty)
        .toList(growable: false);
    if (pages.isEmpty)
      throw StateError('The source returned no readable pages.');

    final target = await _chapterDirectory(anilistId, source.id, chapterUrl);
    final staging = Directory('${target.path}.partial');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    try {
      final manifestPages = <Map<String, dynamic>>[];
      for (var index = 0; index < pages.length; index++) {
        final page = pages[index];
        final imageUrl = '${page['imageUrl']}';
        final rawHeaders = page['headers'];
        final headers = rawHeaders is Map
            ? rawHeaders.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              )
            : const <String, String>{};
        final bytes = await runtime.image(
          source.id,
          imageUrl,
          headers: headers,
        );
        final filename = '${(index + 1).toString().padLeft(4, '0')}.page';
        await File(
          '${staging.path}/$filename',
        ).writeAsBytes(bytes, flush: true);
        manifestPages.add(<String, dynamic>{
          'index': index,
          'file': filename,
          'imageUrl': imageUrl,
          'headers': headers,
        });
        onProgress?.call(index + 1, pages.length);
      }
      await File('${staging.path}/manifest.json').writeAsString(
        jsonEncode(<String, dynamic>{
          'anilistId': anilistId,
          'workTitle': workTitle,
          'sourceId': source.id,
          'sourceName': source.name,
          'chapterUrl': chapterUrl,
          'chapterTitle': chapterTitle,
          'downloadedAt': DateTime.now().millisecondsSinceEpoch,
          'pages': manifestPages,
        }),
        flush: true,
      );
      final backup = Directory('${target.path}.previous');
      if (await backup.exists()) await backup.delete(recursive: true);
      if (await target.exists()) await target.rename(backup.path);
      try {
        await staging.rename(target.path);
        if (await backup.exists()) await backup.delete(recursive: true);
      } catch (_) {
        if (await target.exists()) await target.delete(recursive: true);
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> removeChapter({
    required int anilistId,
    required int sourceId,
    required String chapterUrl,
  }) async {
    final directory = await _chapterDirectory(anilistId, sourceId, chapterUrl);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
