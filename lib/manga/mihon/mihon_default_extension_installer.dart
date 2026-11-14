import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'keiyoushi_extension_repository.dart';
import 'manga_repository_manager.dart';
import 'mihon_runtime.dart';

/// Installs the requested starter Manga sources once, using only the pinned
/// Keiyoushi repository signer and the normal native signature verification.
/// Successful package installs are persisted individually; failed or missing
/// entries are retried on a later app launch, while user-uninstalled packages
/// are not silently reinstalled.
class MihonDefaultExtensionInstaller {
  MihonDefaultExtensionInstaller({
    KeiyoushiExtensionRepository? repository,
    MangaRepositoryManager? repositoryManager,
    MihonRuntimeService? runtime,
    SharedPreferences? preferences,
  }) : _repository = repository ?? KeiyoushiExtensionRepository(),
       _repositoryManager = repositoryManager ?? MangaRepositoryManager(),
       _runtime = runtime ?? MihonRuntimeService.instance,
       _preferences = preferences;

  static final MihonDefaultExtensionInstaller instance =
      MihonDefaultExtensionInstaller();

  /// Keiyoushi's signingKeyFingerprint from its published repo.json.
  /// Auto-installation is deliberately pinned to this exact signer.
  static const String trustedKeiyoushiFingerprint =
      '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2';
  static const String _completedPackagesKey =
      'mihon_default_extensions_completed_v1';

  static const List<String> requestedNames = <String>[
    'AsgardScans',
    'Azora',
    'Manga Starz',
    'Lava Scans',
    'MangaSpark',
    'MangaSwat',
    'MangaTek',
    'MangaTik',
    'Team X',
    'XCOMIC',
  ];

  final KeiyoushiExtensionRepository _repository;
  final MangaRepositoryManager _repositoryManager;
  final MihonRuntimeService _runtime;
  final SharedPreferences? _preferences;
  SharedPreferences? _resolvedPreferences;
  Future<void>? _activeRun;

  Future<SharedPreferences> get _prefs async {
    if (_preferences != null) return _preferences;
    return _resolvedPreferences ??= await SharedPreferences.getInstance();
  }

  Future<void> ensureInstalled() {
    if (!Platform.isAndroid || !_runtime.supportsNativeExtensions) {
      return Future<void>.value();
    }
    final active = _activeRun;
    if (active != null) return active;
    final run = _installMissingDefaults();
    _activeRun = run;
    return run.whenComplete(() {
      _activeRun = null;
    });
  }

  Future<void> _installMissingDefaults() async {
    try {
      // Respect an intentional removal of the Keiyoushi repository by the user.
      final repositories = await _repositoryManager.repositoryUrls();
      if (!repositories.contains(MangaRepositoryManager.defaultRepositoryUrl)) {
        return;
      }

      final preferences = await _prefs;
      final completed = <String>{
        ...(preferences.getStringList(_completedPackagesKey) ??
            const <String>[]),
      };
      if (completed.length >= requestedNames.length) return;
      final entries = await _repository.fetchExtensions(
        repositoryUrl: MangaRepositoryManager.defaultRepositoryUrl,
      );
      final selected = selectDefaultExtensions(entries);
      var installedSources = await _runtime.listSources(reload: true);

      for (final name in requestedNames) {
        final extension = selected[name];
        if (extension == null || !extension.canInstall) continue;
        final packageName = extension.packageName;
        if (completed.contains(packageName)) continue;

        final alreadyInstalled = installedSources.any(
          (source) => source.packageName == packageName,
        );
        if (alreadyInstalled) {
          completed.add(packageName);
          await preferences.setStringList(
            _completedPackagesKey,
            completed.toList()..sort(),
          );
          continue;
        }

        try {
          await _runtime.installExtension(extension);
          completed.add(packageName);
          await preferences.setStringList(
            _completedPackagesKey,
            completed.toList()..sort(),
          );
          // Refresh after each APK so subsequent checks see newly loaded
          // package sources and do not attempt duplicate installs.
          installedSources = await _runtime.listSources(reload: true);
        } catch (error, stackTrace) {
          debugPrint(
            '[MihonDefaults] Could not install $name ($packageName): $error',
          );
          debugPrintStack(stackTrace: stackTrace);
          // Continue with the remaining trusted sources. This package is not
          // marked complete, so a later app launch can retry it.
        }
      }
    } catch (error, stackTrace) {
      // Automatic setup must never prevent the main app from opening.
      debugPrint('[MihonDefaults] Starter-source setup deferred: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Resolve the ten requested display names from the live repository index.
  /// Matching uses names, not package IDs or APK URLs embedded in the app.
  /// When duplicate locale packages exist, Arabic is preferred.
  static Map<String, MangaExtensionEntry> selectDefaultExtensions(
    Iterable<MangaExtensionEntry> entries,
  ) {
    final available = entries
        .where(
          (entry) =>
              entry.canInstall &&
              entry.signingKey?.toLowerCase() == trustedKeiyoushiFingerprint,
        )
        .toList(growable: false);
    final selected = <String, MangaExtensionEntry>{};

    for (final requestedName in requestedNames) {
      final target = normalizeName(requestedName);
      final matches = available
          .where(
            (entry) =>
                normalizeName(entry.name) == target ||
                entry.sources.any(
                  (source) => normalizeName(source.name) == target,
                ),
          )
          .toList(growable: false);
      if (matches.isEmpty) continue;
      final sorted = List<MangaExtensionEntry>.of(matches)
        ..sort((left, right) {
          int localeRank(MangaExtensionEntry entry) {
            if (entry.languages.any(
              (language) => language.toLowerCase() == 'ar',
            )) {
              return 0;
            }
            if (entry.packageName.toLowerCase().contains('.ar.')) return 0;
            return 1;
          }

          final languageOrder = localeRank(left).compareTo(localeRank(right));
          if (languageOrder != 0) return languageOrder;
          final versionOrder = right.versionCode.compareTo(left.versionCode);
          if (versionOrder != 0) return versionOrder;
          return left.packageName.compareTo(right.packageName);
        });
      selected[requestedName] = sorted.first;
    }
    return Map<String, MangaExtensionEntry>.unmodifiable(selected);
  }

  static String normalizeName(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^tachiyomi\s*:\s*', caseSensitive: false), '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}
