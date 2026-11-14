import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../manga/mihon/manga_repository_manager.dart';
import '../../manga/mihon/mihon_source_browser_screen.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../ui_components/app_ui_components.dart';
import '../../video_providers/unified/source_manifest.dart';
import '../../video_providers/unified/source_priority_manager.dart';
import '../../video_providers/unified/source_priority_policy.dart';
import '../../video_providers/unified/source_repository_manager.dart';
import '../../video_providers/unified/source_repository_revision.dart';
import '../../video_providers/unified/unified_source_service.dart';
import 'quickjs_source_settings_dialog.dart';

/// User-facing management for source repositories and their installed engines.
/// Unsupported engines remain visible, but are never executed by the runtime.
class SourceRepositoriesScreen extends StatefulWidget {
  const SourceRepositoriesScreen({
    this.embedded = false,
    this.priorityOnly = false,
    super.key,
  });

  /// Render inside a host tab rather than creating a second Scaffold/AppBar.
  final bool embedded;

  /// Show only the source-priority editor (used from Synchronize).
  final bool priorityOnly;

  @override
  State<SourceRepositoriesScreen> createState() =>
      _SourceRepositoriesScreenState();
}

class _SourceRepositoriesScreenState extends State<SourceRepositoriesScreen> {
  final UnifiedSourceService _service = UnifiedSourceService();
  final TextEditingController _repositoryController = TextEditingController();
  final TextEditingController _mangaRepositoryController =
      TextEditingController();
  final TextEditingController _catalogSearchController =
      TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  static const int _catalogPageSize = 10;
  int _catalogVisibleCount = _catalogPageSize;
  bool _expandingCatalog = false;
  final MangaRepositoryManager _mangaRepositoryManager =
      MangaRepositoryManager();

  bool _loading = true;
  bool _working = false;
  SourceRepositorySyncResult? _snapshot;
  List<String> _repositories = const <String>[];
  List<String> _mangaRepositories = const <String>[];
  Map<String, List<SourceRepositoryRevision>> _repositoryHistory =
      <String, List<SourceRepositoryRevision>>{};
  Map<String, String?> _repositoryPins = <String, String?>{};
  Set<String> _installed = <String>{};
  Set<String> _disabledDefaults = <String>{};
  Map<SourcePriorityCategory, List<String>> _priorityKeys =
      <SourcePriorityCategory, List<String>>{
        for (final category in SourcePriorityCategory.values)
          category: const <String>[],
      };
  Map<SourcePriorityCategory, List<String>> _backupKeys =
      <SourcePriorityCategory, List<String>>{
        for (final category in SourcePriorityCategory.values)
          category: const <String>[],
      };
  SourcePriorityCategory _priorityCategory = SourcePriorityCategory.movies;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _catalogSearchController.addListener(_onCatalogSearchChanged);
    _pageScrollController.addListener(_onPageScroll);
    _refresh();
  }

  @override
  void dispose() {
    _repositoryController.dispose();
    _mangaRepositoryController.dispose();
    _catalogSearchController
      ..removeListener(_onCatalogSearchChanged)
      ..dispose();
    _pageScrollController
      ..removeListener(_onPageScroll)
      ..dispose();
    super.dispose();
  }

  void _onCatalogSearchChanged() {
    if (!mounted) return;
    setState(() => _catalogVisibleCount = _catalogPageSize);
  }

  List<SourceManifest> _filteredCatalog(List<SourceManifest> catalog) {
    final query = _catalogSearchController.text.trim().toLowerCase();
    final results = catalog
        .where((source) {
          if (query.isEmpty) return true;
          return source.name.toLowerCase().contains(query) ||
              source.stableKey.toLowerCase().contains(query) ||
              source.language.toLowerCase().contains(query);
        })
        .toList(growable: false);
    results.sort((left, right) {
      final leftInstalled = _isInstalled(left);
      final rightInstalled = _isInstalled(right);
      if (leftInstalled != rightInstalled) return leftInstalled ? -1 : 1;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return results;
  }

  void _onPageScroll() {
    if (!mounted ||
        widget.priorityOnly ||
        _expandingCatalog ||
        !_pageScrollController.hasClients ||
        _loading) {
      return;
    }
    if (_pageScrollController.position.extentAfter > 420) return;
    final total = _filteredCatalog(
      _snapshot?.catalog ?? const <SourceManifest>[],
    ).length;
    if (_catalogVisibleCount >= total) return;
    _expandingCatalog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _catalogVisibleCount += _catalogPageSize);
      _expandingCatalog = false;
    });
  }

  Future<void> _refresh({
    bool showBusy = true,
    bool forceRefresh = true,
  }) async {
    if (showBusy && mounted) setState(() => _loading = true);
    try {
      var snapshot = await _service.refreshRepositories(
        forceRefresh: forceRefresh,
      );
      final configured = await _service.configureRecommendedSources(snapshot);
      if (configured) {
        snapshot = await _service.refreshRepositories(forceRefresh: false);
      }
      final priorityKeys = <SourcePriorityCategory, List<String>>{};
      final backupKeys = <SourcePriorityCategory, List<String>>{};
      for (final category in SourcePriorityCategory.values) {
        priorityKeys[category] = await _service.priorityKeys(category);
        backupKeys[category] = await _service.backupKeys(category);
      }
      final repositories = await _service.repositoryUrls();
      final mangaRepositories = await _mangaRepositoryManager.repositoryUrls();
      final history = <String, List<SourceRepositoryRevision>>{};
      final pins = <String, String?>{};
      for (final url in repositories) {
        history[url] = await _service.repositoryRevisions(url);
        pins[url] = await _service.pinnedRepositoryCommit(url);
      }
      final installed = await _service.installedSourceKeys();
      final disabledDefaults = await _service.disabledDefaultSourceKeys();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _catalogVisibleCount = _catalogPageSize;
        _repositories = repositories;
        _mangaRepositories = mangaRepositories;
        _repositoryHistory = history;
        _repositoryPins = pins;
        _installed = installed;
        _disabledDefaults = disabledDefaults;
        _priorityKeys = priorityKeys;
        _backupKeys = backupKeys;
        _pageError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pageError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addRepository([String? suppliedUrl]) async {
    final url = (suppliedUrl ?? _repositoryController.text).trim();
    if (url.isEmpty || _working) return;
    setState(() => _working = true);
    try {
      await _service.addRepository(url);
      _repositoryController.clear();
      await _refresh(showBusy: false);
      if (mounted) _message(tr('source_repository_added'));
    } catch (error) {
      if (mounted) _message(_repositoryAddError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _repositoryAddError(Object error) {
    final message = error is FormatException ? error.message.toString() : '';
    final isMediaUrl =
        message.contains('media playlist or stream URL') ||
        message.contains('M3U/HLS media playlist');
    if (!isMediaUrl) return '${tr('repository_error')}: $error';
    return Localizations.localeOf(context).languageCode == 'ar'
        ? 'هذا رابط قائمة بث أو رابط فيديو، وليس فهرس مستودع. أضف قائمة M3U من Live TV ثم IPTV / M3U > إدارة قوائم IPTV.'
        : 'This is a playlist or media URL, not a source repository index. Add M3U lists from Live TV > IPTV / M3U > Manage IPTV playlists.';
  }

  Future<void> _addBundledRepositories() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _service.addDefaultRepositories();
      await _refresh(showBusy: false);
      if (mounted) _message(tr('bundled_repositories_refreshed'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _addMangaRepository() async {
    final url = _mangaRepositoryController.text.trim();
    if (url.isEmpty || _working) return;
    setState(() => _working = true);
    try {
      await _mangaRepositoryManager.addRepository(url);
      _mangaRepositoryController.clear();
      await _refresh(showBusy: false, forceRefresh: false);
      if (mounted) _message(tr('manga_repository_added'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editMangaRepository(String oldUrl) async {
    final controller = TextEditingController(text: oldUrl);
    final updatedUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('manga_repository_edit')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr('manga_repository_url'),
            hintText: 'https://example.com/index.pb',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updatedUrl == null || updatedUrl.trim() == oldUrl || _working) return;
    setState(() => _working = true);
    try {
      await _mangaRepositoryManager.updateRepository(oldUrl, updatedUrl);
      await _refresh(showBusy: false, forceRefresh: false);
      if (mounted) _message(tr('manga_repository_updated'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _removeMangaRepository(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('manga_repository_remove')),
        content: Text(url),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || _working) return;
    setState(() => _working = true);
    try {
      await _mangaRepositoryManager.removeRepository(url);
      await _refresh(showBusy: false, forceRefresh: false);
      if (mounted) _message(tr('manga_repository_removed'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _removeRepository(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('remove_repository')),
        content: Text(_safeRepositoryDisplayUrl(url)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.removeRepository(url);
      await _refresh(showBusy: false);
      if (mounted) _message(tr('source_repository_removed'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    }
  }

  Future<void> _previewRepository(String url) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final preview = await _service.previewRepositoryUpdate(url);
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('repository_update_preview')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    preview.hasChanges
                        ? tr('repository_update_changes_found')
                        : tr('repository_no_update_changes'),
                  ),
                  const SizedBox(height: 12),
                  _DiffCountRow(
                    label: tr('repository_changed_documents'),
                    count: preview.changedDocumentCount,
                  ),
                  _DiffCountRow(
                    label: tr('repository_added_sources'),
                    count: preview.addedSourceIds.length,
                  ),
                  _DiffCountRow(
                    label: tr('repository_removed_sources'),
                    count: preview.removedSourceIds.length,
                  ),
                  _DiffCountRow(
                    label: tr('repository_modified_sources'),
                    count: preview.changedSourceIds.length,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${tr('repository_candidate_hash')}: ${preview.candidateHash.substring(0, 16)}…',
                    style: AppType.metadata,
                  ),
                  if (preview.addedSourceIds.isNotEmpty ||
                      preview.removedSourceIds.isNotEmpty ||
                      preview.changedSourceIds.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    for (final entry in <({String title, List<String> ids})>[
                      (
                        title: tr('repository_added_sources'),
                        ids: preview.addedSourceIds,
                      ),
                      (
                        title: tr('repository_removed_sources'),
                        ids: preview.removedSourceIds,
                      ),
                      (
                        title: tr('repository_modified_sources'),
                        ids: preview.changedSourceIds,
                      ),
                    ])
                      if (entry.ids.isNotEmpty) ...<Widget>[
                        Text(entry.title, style: AppType.metadata),
                        Text(
                          entry.ids.take(8).join(', ') +
                              (entry.ids.length > 8 ? ' …' : ''),
                          style: AppType.metadata.copyWith(
                            color: AppPalette.of(context).mutedText,
                          ),
                        ),
                      ],
                  ],
                  const SizedBox(height: 12),
                  Text(
                    tr('repository_hash_not_trust_badge'),
                    style: AppType.metadata.copyWith(
                      color: AppPalette.of(context).mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('cancel')),
            ),
            if (preview.hasChanges)
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(tr('repository_apply_update')),
              ),
          ],
        ),
      );
      if (accepted == true) {
        await _service.applyPreviewedRepositoryUpdate(preview);
        await _refresh(showBusy: false, forceRefresh: false);
        if (mounted) _message(tr('repository_update_applied'));
      }
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _rollbackRepository(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('repository_rollback')),
        content: Text(tr('repository_rollback_confirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('repository_rollback')),
          ),
        ],
      ),
    );
    if (confirmed != true || _working) return;
    setState(() => _working = true);
    try {
      final revision = await _service.rollbackRepository(url);
      if (revision == null) {
        if (mounted) _message(tr('repository_no_rollback_available'));
        return;
      }
      await _refresh(showBusy: false);
      if (mounted) _message(tr('repository_rollback_applied'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pinRepository(String url) async {
    final controller = TextEditingController(text: _repositoryPins[url] ?? '');
    final commit = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('repository_pin_commit')),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 40,
          decoration: InputDecoration(
            hintText: tr('repository_commit_sha_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (commit == null || commit.trim().isEmpty || _working) return;
    setState(() => _working = true);
    try {
      await _service.pinRepositoryToCommit(url, commit.trim());
      await _refresh(showBusy: false);
      if (mounted) _message(tr('repository_commit_pinned'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _clearRepositoryPin(String url) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _service.clearRepositoryPin(url);
      await _service.resumeRepositoryUpdates(url);
      await _refresh(showBusy: false);
      if (mounted) _message(tr('repository_commit_pin_cleared'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reviewPotentialDuplicates() async {
    final sources = _snapshot?.catalog ?? const <SourceManifest>[];
    if (_working || sources.length < 2) return;
    setState(() => _working = true);
    try {
      final duplicates = await _service.findPotentialDuplicates(sources);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('repository_duplicate_review')),
          content: SizedBox(
            width: 560,
            child: duplicates.isEmpty
                ? Text(tr('repository_no_duplicates'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: duplicates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final candidate = duplicates[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${candidate.first.name} ↔ ${candidate.second.name}',
                              style: AppType.cardTitle,
                            ),
                            Text(
                              candidate.reasons
                                  .map(_duplicateReasonLabel)
                                  .join(' • '),
                              style: AppType.metadata.copyWith(
                                color: AppPalette.of(context).mutedText,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('close')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _duplicateReasonLabel(String reason) => switch (reason) {
    'source-identity' => tr('repository_duplicate_identity'),
    'canonical-script-url' => tr('repository_duplicate_script_url'),
    'name-and-domain' => tr('repository_duplicate_name_domain'),
    'script-content-hash' => tr('repository_duplicate_script_hash'),
    _ => reason,
  };

  Future<void> _openSourceProvenance(SourceManifest source) async {
    try {
      final provenance = await _service.provenanceOf(source);
      if (!mounted) return;
      final repositoryUri = Uri.tryParse(provenance.repositoryUrl ?? '');
      final safeRepositoryUrl =
          repositoryUri == null || repositoryUri.host.isEmpty
          ? null
          : repositoryUri
                .replace(userInfo: '', query: '', fragment: '')
                .toString();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('source_provenance')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ProvenanceRow(
                    label: tr('provenance_source_name'),
                    value: provenance.sourceName,
                  ),
                  _ProvenanceRow(
                    label: tr('provenance_version'),
                    value: provenance.version,
                  ),
                  _ProvenanceRow(
                    label: tr('provenance_authors'),
                    value: provenance.authors.isEmpty
                        ? tr('unknown')
                        : provenance.authors.join(', '),
                  ),
                  _ProvenanceRow(
                    label: tr('provenance_engine'),
                    value: provenance.engineType,
                  ),
                  if (safeRepositoryUrl != null)
                    _ProvenanceRow(
                      label: tr('source_repository_url'),
                      value: safeRepositoryUrl,
                    ),
                  if (provenance.scriptUrl != null)
                    _ProvenanceRow(
                      label: tr('provenance_script_url'),
                      value: provenance.scriptUrl!,
                    ),
                  if (provenance.commitHash != null)
                    _ProvenanceRow(
                      label: tr('repository_pinned_commit'),
                      value: provenance.commitHash!,
                    ),
                  if (provenance.scriptHash != null)
                    _ProvenanceRow(
                      label: 'SHA-256',
                      value: provenance.scriptHash!,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    tr('repository_hash_not_trust_badge'),
                    style: AppType.metadata.copyWith(
                      color: AppPalette.of(context).mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('close')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    }
  }

  Future<void> _openQuickJsSettings(SourceManifest source) async {
    try {
      final saved = await QuickJsSourceSettingsDialog.show(context, source);
      if (saved == true && mounted) _message(tr('quickjs_settings_saved'));
    } catch (error) {
      if (mounted) _message('${tr('quickjs_settings_load_error')}: $error');
    }
  }

  Future<void> _openStremioConfiguration(SourceManifest source) async {
    final rawUrl = source.engine.config['configurationUrl'];
    final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      if (mounted) _message(tr('stremio_configuration_unavailable'));
      return;
    }

    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('stremio_configuration_title')),
        content: Text(tr('stremio_configuration_instructions')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('open')),
          ),
        ],
      ),
    );
    if (open != true) return;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _message(tr('stremio_configuration_unavailable'));
      }
    } catch (_) {
      if (mounted) _message(tr('stremio_configuration_unavailable'));
    }
  }

  Future<void> _setInstalled(SourceManifest source, bool install) async {
    try {
      if (install) {
        await _service.installSource(source);
      } else {
        await _service.uninstallSource(source);
      }
      await _refresh(showBusy: false);
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    }
  }

  bool _isInstalled(SourceManifest source) =>
      _installed.contains(source.stableKey) ||
      (source.installedByDefault &&
          !_disabledDefaults.contains(source.stableKey));

  bool _supportsRuntime(SourceManifest source) =>
      _service.supportsSource(source);

  Future<void> _copyConfiguration() async {
    try {
      final raw = await _service.exportConfiguration();
      await Clipboard.setData(ClipboardData(text: raw));
      if (mounted) _message(tr('configuration_copied'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    }
  }

  Future<void> _importConfiguration() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('import_source_configuration')),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: tr('paste_source_configuration'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(tr('import')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    try {
      await _service.importConfiguration(raw);
      await _refresh();
      if (mounted) _message(tr('configuration_imported'));
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final catalog = _snapshot?.catalog ?? const <SourceManifest>[];
    final filteredCatalog = _filteredCatalog(catalog);
    final visibleCatalog = filteredCatalog
        .take(_catalogVisibleCount)
        .toList(growable: false);
    final installedSources = catalog
        .where(_isInstalled)
        .toList(growable: false);
    final unsupportedCount = installedSources
        .where((source) => !_supportsRuntime(source))
        .length;

    if (widget.priorityOnly) {
      final priorityBody = AppResponsiveContent(
        maxWidth: 900,
        child: _loading && _snapshot == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter(context),
                  AppSpace.md,
                  AppSpace.gutter(context),
                  AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
                ),
                children: <Widget>[_buildPriorityRepositoriesSection(catalog)],
              ),
      );
      if (widget.embedded) return priorityBody;
      return Scaffold(
        backgroundColor: palette.page,
        appBar: PageAppBar(title: tr('tv_choose_source_priority')),
        body: priorityBody,
      );
    }

    final managerBody = AppResponsiveContent(
      maxWidth: 900,
      child: _loading && _snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter(context),
                AppSpace.md,
                AppSpace.gutter(context),
                AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
              ),
              controller: _pageScrollController,
              children: <Widget>[
                if (widget.embedded) _buildEmbeddedToolbar(),
                _IntroCard(
                  description: tr('source_manager_description'),
                  installedCount: installedSources.length,
                  catalogCount: catalog.length,
                  unsupportedCount: unsupportedCount,
                ),
                const SizedBox(height: AppSpace.lg),
                _SectionHeading(title: tr('add_source_repository')),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? 'مهم: هذا الحقل مخصص لفهارس مستودعات المصادر بصيغة JSON فقط. قوائم القنوات M3U/M3U8 تُضاف من Live TV ثم IPTV / M3U، أما روابط HLS/DASH المباشرة فتُوضع داخل قائمة القنوات.'
                        : 'Important: this field accepts JSON source-repository indexes only. Add M3U/M3U8 channel lists from Live TV > IPTV / M3U. Direct HLS/DASH stream URLs belong inside a channel playlist.',
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ),
                Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      children: <Widget>[
                        TextField(
                          controller: _repositoryController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _addRepository(),
                          decoration: InputDecoration(
                            labelText: tr('source_repository_url'),
                            hintText: 'https://example.com/index.json',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: tr('add_repository'),
                              onPressed: _working ? null : _addRepository,
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton.icon(
                            onPressed: _working
                                ? null
                                : _addBundledRepositories,
                            icon: const Icon(Icons.add_link_rounded),
                            label: Text(tr('add_all_bundled_repositories')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _SectionHeading(
                  title: tr('repositories'),
                  trailing: Text(
                    '${_repositories.length + _mangaRepositories.length}',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Text(
                    '${_repositories.length} ${tr('video_repositories')} · ${_mangaRepositories.length} ${tr('manga_repositories')}',
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ),
                _SectionHeading(
                  title: tr('video_repositories'),
                  trailing: Text('${_repositories.length}'),
                ),
                if (_repositories.isEmpty)
                  _EmptyPanel(label: tr('no_repositories'))
                else
                  _SurfacePanel(
                    children: <Widget>[
                      for (var index = 0; index < _repositories.length; index++)
                        _RepositoryTile(
                          url: _repositories[index],
                          error: _snapshot?.errors[_repositories[index]],
                          revisionCount:
                              _repositoryHistory[_repositories[index]]
                                  ?.length ??
                              0,
                          latestRevision:
                              (_repositoryHistory[_repositories[index]]
                                      ?.isNotEmpty ==
                                  true)
                              ? _repositoryHistory[_repositories[index]]!.first
                              : null,
                          pinnedCommit: _repositoryPins[_repositories[index]],
                          isGitHubRaw:
                              Uri.tryParse(_repositories[index])?.host ==
                              'raw.githubusercontent.com',
                          onPreview: () =>
                              _previewRepository(_repositories[index]),
                          onRollback: () =>
                              _rollbackRepository(_repositories[index]),
                          onPin: () => _pinRepository(_repositories[index]),
                          onClearPin: () =>
                              _clearRepositoryPin(_repositories[index]),
                          onRemove: () =>
                              _removeRepository(_repositories[index]),
                          showDivider: index != _repositories.length - 1,
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpace.lg),
                _SectionHeading(
                  title: tr('manga_repositories'),
                  trailing: Text('${_mangaRepositories.length}'),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Text(
                    tr('manga_repository_separate_hint'),
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ),
                Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.menu_book_rounded,
                              color: palette.foreground,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(
                                tr('manga_repository_add_url'),
                                style: AppType.cardTitle.copyWith(
                                  color: palette.foreground,
                                ),
                              ),
                            ),
                            const Chip(label: Text('Protobuf')),
                          ],
                        ),
                        const SizedBox(height: AppSpace.sm),
                        TextField(
                          controller: _mangaRepositoryController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _addMangaRepository(),
                          decoration: InputDecoration(
                            labelText: tr('manga_repository_url'),
                            hintText: 'https://example.com/index.pb',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: tr('add_repository'),
                              onPressed: _working ? null : _addMangaRepository,
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          tr('manga_repository_pb_only_hint'),
                          style: AppType.metadata.copyWith(
                            color: palette.mutedText,
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        if (_mangaRepositories.isEmpty)
                          _EmptyPanel(label: tr('manga_repository_empty'))
                        else
                          _SurfacePanel(
                            children: <Widget>[
                              for (
                                var index = 0;
                                index < _mangaRepositories.length;
                                index++
                              )
                                _MangaRepositoryTile(
                                  url: _mangaRepositories[index],
                                  showDivider:
                                      index != _mangaRepositories.length - 1,
                                  onEdit: () => _editMangaRepository(
                                    _mangaRepositories[index],
                                  ),
                                  onRemove: () => _removeMangaRepository(
                                    _mangaRepositories[index],
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: AppSpace.md),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton.icon(
                            onPressed: _working
                                ? null
                                : () => Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const MihonSourceBrowserScreen(),
                                    ),
                                  ),
                            icon: const Icon(Icons.menu_book_rounded),
                            label: Text(tr('mihon_sources')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _SectionHeading(
                  title: tr('source_catalog'),
                  trailing: Text('${catalog.length}'),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: TextField(
                    controller: _catalogSearchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: tr('search_sources'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _catalogSearchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: tr('clear'),
                              onPressed: _catalogSearchController.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                if (_pageError != null)
                  _EmptyPanel(label: _pageError!, isError: true)
                else if (catalog.isEmpty)
                  _EmptyPanel(label: tr('no_sources_found'))
                else if (filteredCatalog.isEmpty)
                  _EmptyPanel(label: tr('no_sources_found'))
                else
                  _SurfacePanel(
                    children: <Widget>[
                      for (
                        var index = 0;
                        index < visibleCatalog.length;
                        index++
                      )
                        _SourceTile(
                          source: visibleCatalog[index],
                          installed: _isInstalled(visibleCatalog[index]),
                          supported: _supportsRuntime(visibleCatalog[index]),
                          onChanged: (value) =>
                              _setInstalled(visibleCatalog[index], value),
                          onProvenance: () =>
                              _openSourceProvenance(visibleCatalog[index]),
                          onSettings:
                              visibleCatalog[index].engine.kind ==
                                      SourceEngineKind.javascript &&
                                  _isInstalled(visibleCatalog[index])
                              ? () =>
                                    _openQuickJsSettings(visibleCatalog[index])
                              : null,
                          onConfigure:
                              visibleCatalog[index].engine.kind ==
                                      SourceEngineKind.stremio &&
                                  (visibleCatalog[index]
                                              .engine
                                              .config['configurable'] ==
                                          true ||
                                      visibleCatalog[index]
                                              .engine
                                              .config['configurationRequired'] ==
                                          true) &&
                                  visibleCatalog[index]
                                          .engine
                                          .config['configurationUrl']
                                      is String
                              ? () => _openStremioConfiguration(
                                  visibleCatalog[index],
                                )
                              : null,
                          configurationRequired:
                              visibleCatalog[index]
                                  .engine
                                  .config['configurationRequired'] ==
                              true,
                          configurable:
                              visibleCatalog[index]
                                  .engine
                                  .config['configurable'] ==
                              true,
                          showDivider: index != visibleCatalog.length - 1,
                        ),
                    ],
                  ),
                if (visibleCatalog.length < filteredCatalog.length)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.xs),
                    child: Text(
                      '${visibleCatalog.length} / ${filteredCatalog.length}',
                      style: AppType.metadata.copyWith(
                        color: palette.mutedText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_snapshot?.errors.isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    tr('some_repositories_failed'),
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ],
              ],
            ),
    );
    if (widget.embedded) return managerBody;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: _buildPageAppBar(),
      body: managerBody,
    );
  }

  PreferredSizeWidget _buildPageAppBar() => PageAppBar(
    title: tr('source_manager'),
    contentWidth: 900,
    actions: <Widget>[
      IconButton(
        tooltip: tr('refresh_sources'),
        onPressed: _loading ? null : () => _refresh(),
        icon: const Icon(Icons.refresh_rounded),
      ),
      _buildConfigurationMenu(),
    ],
  );

  Widget _buildEmbeddedToolbar() => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Wrap(
      spacing: AppSpace.xs,
      children: <Widget>[
        IconButton(
          tooltip: tr('refresh_sources'),
          onPressed: _loading ? null : () => _refresh(),
          icon: const Icon(Icons.refresh_rounded),
        ),
        _buildConfigurationMenu(),
      ],
    ),
  );

  Widget _buildConfigurationMenu() => PopupMenuButton<String>(
    tooltip: tr('source_configuration'),
    onSelected: (value) {
      switch (value) {
        case 'export':
          _copyConfiguration();
          break;
        case 'import':
          _importConfiguration();
          break;
        case 'duplicates':
          _reviewPotentialDuplicates();
          break;
      }
    },
    itemBuilder: (_) => <PopupMenuEntry<String>>[
      PopupMenuItem(value: 'export', child: Text(tr('export_configuration'))),
      PopupMenuItem(value: 'import', child: Text(tr('import_configuration'))),
      PopupMenuItem(
        value: 'duplicates',
        child: Text(tr('repository_duplicate_review')),
      ),
    ],
  );

  List<SourceManifest> _prioritySources(
    SourcePriorityCategory category,
    List<SourceManifest> catalog,
    SourcePriorityLane lane,
  ) {
    final byKey = <String, SourceManifest>{
      for (final source in catalog) source.stableKey: source,
    };
    final keys = lane == SourcePriorityLane.primary
        ? (_priorityKeys[category] ?? const <String>[])
        : (_backupKeys[category] ?? const <String>[]);
    return keys
        .map((key) => byKey[key])
        .whereType<SourceManifest>()
        .toList(growable: false);
  }

  Future<void> _changePriorityOrder(
    SourcePriorityLane lane,
    int oldIndex,
    int newIndex,
  ) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _service.reorderPrioritySource(
        _priorityCategory,
        lane: lane,
        oldIndex: oldIndex,
        newIndex: newIndex,
      );
      await _refresh(showBusy: false, forceRefresh: false);
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _addPriority() async {
    if (_working || _snapshot == null) return;
    final category = _priorityCategory;
    final catalog = List<SourceManifest>.of(_snapshot!.catalog);
    var primary = List<String>.of(_priorityKeys[category] ?? const <String>[]);
    var backup = List<String>.of(_backupKeys[category] ?? const <String>[]);
    var selectedLane = primary.length < SourcePriorityManager.maxPrimarySources
        ? SourcePriorityLane.primary
        : backup.length < SourcePriorityManager.maxBackupSources
        ? SourcePriorityLane.backup
        : SourcePriorityLane.primary;
    var showCapacityError = false;
    var dialogWorking = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) {
          final allFull =
              primary.length >= SourcePriorityManager.maxPrimarySources &&
              backup.length >= SourcePriorityManager.maxBackupSources;
          final selectedFull = selectedLane == SourcePriorityLane.primary
              ? primary.length >= SourcePriorityManager.maxPrimarySources
              : backup.length >= SourcePriorityManager.maxBackupSources;
          final orderedCatalog = List<SourceManifest>.of(catalog)
            ..sort((left, right) {
              int rank(SourceManifest source) {
                final primaryIndex = primary.indexOf(source.stableKey);
                if (primaryIndex >= 0) return primaryIndex;
                final backupIndex = backup.indexOf(source.stableKey);
                if (backupIndex >= 0) return 1000 + backupIndex;
                return 100000;
              }

              final leftRank = rank(left);
              final rightRank = rank(right);
              if (leftRank != rightRank) return leftRank.compareTo(rightRank);
              return left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              );
            });

          return AlertDialog(
            title: Text(
              _isArabic(dialogContext)
                  ? 'إضافة / إدارة السيرفرات'
                  : 'Add / Manage sources',
            ),
            content: SizedBox(
              width: MediaQuery.sizeOf(dialogContext).width * 0.9,
              height: MediaQuery.sizeOf(dialogContext).height * 0.56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SegmentedButton<SourcePriorityLane>(
                    segments: <ButtonSegment<SourcePriorityLane>>[
                      ButtonSegment<SourcePriorityLane>(
                        value: SourcePriorityLane.primary,
                        label: Text(
                          _isArabic(dialogContext) ? 'الرئيسية' : 'Primary',
                        ),
                      ),
                      ButtonSegment<SourcePriorityLane>(
                        value: SourcePriorityLane.backup,
                        label: Text(
                          _isArabic(dialogContext) ? 'الاحتياطية' : 'Backup',
                        ),
                      ),
                    ],
                    selected: <SourcePriorityLane>{selectedLane},
                    onSelectionChanged: _working || dialogWorking
                        ? null
                        : (selection) => updateDialog(() {
                            selectedLane = selection.first;
                            showCapacityError = false;
                          }),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    _isArabic(dialogContext)
                        ? 'الرئيسية: ${primary.length}/20  ·  الاحتياطية: ${backup.length}/30'
                        : 'Primary: ${primary.length}/20  ·  Backup: ${backup.length}/30',
                    style: AppType.metadata.copyWith(
                      color: AppPalette.of(dialogContext).mutedText,
                    ),
                  ),
                  if (allFull || selectedFull || showCapacityError) ...<Widget>[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      allFull
                          ? (_isArabic(dialogContext)
                                ? 'لا توجد خانات فارغة في أي من القائمتين.'
                                : 'There are no empty slots in either list.')
                          : (_isArabic(dialogContext)
                                ? 'القائمة المحددة ممتلئة. اختر القائمة الأخرى أو أزل سيرفرًا موجودًا.'
                                : 'The selected list is full. Choose the other list or remove an existing source.'),
                      style: AppType.metadata.copyWith(
                        color: Theme.of(dialogContext).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.sm),
                  Expanded(
                    child: ListView.separated(
                      itemCount: orderedCatalog.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (itemContext, index) {
                        final source = orderedCatalog[index];
                        final inPrimary = primary.contains(source.stableKey);
                        final inBackup = backup.contains(source.stableKey);
                        final existingLane = inPrimary
                            ? SourcePriorityLane.primary
                            : inBackup
                            ? SourcePriorityLane.backup
                            : null;
                        final isAdded = existingLane != null;
                        final laneLabel =
                            existingLane == SourcePriorityLane.primary
                            ? (_isArabic(dialogContext)
                                  ? 'الرئيسية'
                                  : 'Primary')
                            : (_isArabic(dialogContext)
                                  ? 'الاحتياطية'
                                  : 'Backup');
                        final canAdd = !isAdded && !selectedFull && !allFull;

                        return ListTile(
                          dense: true,
                          title: Text(
                            source.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            isAdded
                                ? '${source.language} · $laneLabel · ${SourcePriorityPolicy.statusLabel(source)}'
                                : '${source.language} · ${SourcePriorityPolicy.statusLabel(source)}',
                            maxLines: 2,
                          ),
                          trailing: IconButton(
                            tooltip: isAdded
                                ? (_isArabic(dialogContext)
                                      ? 'حذف من القائمة'
                                      : 'Remove from list')
                                : (_isArabic(dialogContext)
                                      ? 'إضافة إلى القائمة المحددة'
                                      : 'Add to selected list'),
                            onPressed: _working || dialogWorking
                                ? null
                                : () async {
                                    if (isAdded) {
                                      final confirmed = await showDialog<bool>(
                                        context: dialogContext,
                                        builder: (confirmContext) => AlertDialog(
                                          title: Text(
                                            _isArabic(confirmContext)
                                                ? 'تأكيد حذف السيرفر'
                                                : 'Confirm source removal',
                                          ),
                                          content: Text(
                                            _isArabic(confirmContext)
                                                ? 'هل تريد إزالة ${source.name} من القائمة $laneLabel؟ سيبقى مثبتًا ضمن المستودع.'
                                                : 'Remove ${source.name} from the $laneLabel list? The source will remain installed in its repository.',
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                confirmContext,
                                                false,
                                              ),
                                              child: Text(tr('cancel')),
                                            ),
                                            FilledButton.tonal(
                                              onPressed: () => Navigator.pop(
                                                confirmContext,
                                                true,
                                              ),
                                              child: Text(tr('remove')),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed != true ||
                                          !mounted ||
                                          !dialogContext.mounted) {
                                        return;
                                      }
                                      final laneToRemove = existingLane;
                                      updateDialog(() => dialogWorking = true);
                                      setState(() => _working = true);
                                      try {
                                        await _service.removePrioritySource(
                                          category,
                                          source,
                                          lane: laneToRemove,
                                        );
                                        if (laneToRemove ==
                                            SourcePriorityLane.primary) {
                                          primary.remove(source.stableKey);
                                        } else {
                                          backup.remove(source.stableKey);
                                        }
                                        if (dialogContext.mounted) {
                                          updateDialog(() {});
                                        }
                                        await _refresh(
                                          showBusy: false,
                                          forceRefresh: false,
                                        );
                                      } catch (error) {
                                        if (mounted) {
                                          _message(
                                            '${tr('repository_error')}: $error',
                                          );
                                        }
                                      } finally {
                                        if (dialogContext.mounted) {
                                          updateDialog(
                                            () => dialogWorking = false,
                                          );
                                        }
                                        if (mounted) {
                                          setState(() => _working = false);
                                        }
                                      }
                                      return;
                                    }

                                    if (!canAdd) {
                                      updateDialog(() {
                                        showCapacityError = true;
                                      });
                                      return;
                                    }
                                    updateDialog(() => dialogWorking = true);
                                    setState(() => _working = true);
                                    try {
                                      final added = await _service
                                          .addPrioritySource(
                                            category,
                                            source,
                                            lane: selectedLane,
                                          );
                                      if (!added) {
                                        if (dialogContext.mounted) {
                                          updateDialog(() {
                                            showCapacityError = true;
                                          });
                                        }
                                        return;
                                      }
                                      if (selectedLane ==
                                          SourcePriorityLane.primary) {
                                        primary.add(source.stableKey);
                                      } else {
                                        backup.add(source.stableKey);
                                      }
                                      if (dialogContext.mounted) {
                                        updateDialog(() {
                                          showCapacityError = false;
                                        });
                                      }
                                      await _refresh(
                                        showBusy: false,
                                        forceRefresh: false,
                                      );
                                    } catch (error) {
                                      if (mounted) {
                                        _message(
                                          '${tr('repository_error')}: $error',
                                        );
                                      }
                                    } finally {
                                      if (dialogContext.mounted) {
                                        updateDialog(
                                          () => dialogWorking = false,
                                        );
                                      }
                                      if (mounted) {
                                        setState(() => _working = false);
                                      }
                                    }
                                  },
                            icon: Icon(
                              isAdded
                                  ? Icons.remove_circle_outline_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: isAdded
                                  ? Theme.of(dialogContext).colorScheme.error
                                  : canAdd
                                  ? Theme.of(dialogContext).colorScheme.primary
                                  : AppPalette.of(dialogContext).mutedText,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: dialogWorking
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text(tr('done')),
              ),
            ],
          );
        },
      ),
    );
    await _refresh(showBusy: false, forceRefresh: false);
  }

  Future<void> _swapPriority(SourceManifest current) async {
    if (_working || _snapshot == null) return;
    final category = _priorityCategory;
    final catalog = _snapshot!.catalog;
    final primary = _prioritySources(
      category,
      catalog,
      SourcePriorityLane.primary,
    );
    final backup = _prioritySources(
      category,
      catalog,
      SourcePriorityLane.backup,
    );
    final replacement = await showDialog<SourceManifest>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_isArabic(dialogContext) ? 'تبديل السيرفر' : 'Swap source'),
        content: SizedBox(
          width: MediaQuery.sizeOf(dialogContext).width * 0.9,
          height: MediaQuery.sizeOf(dialogContext).height * 0.58,
          child: ListView(
            children: <Widget>[
              _SwapListHeading(
                title: _isArabic(dialogContext)
                    ? 'القائمة الرئيسية'
                    : 'PRIMARY LIST',
                count: primary.length,
                limit: SourcePriorityManager.maxPrimarySources,
              ),
              for (final source in primary)
                if (source.stableKey != current.stableKey)
                  ListTile(
                    dense: true,
                    title: Text(source.name),
                    subtitle: Text(
                      _isArabic(dialogContext) ? 'رئيسية' : 'Primary',
                    ),
                    onTap: () => Navigator.pop(dialogContext, source),
                  ),
              const Divider(),
              _SwapListHeading(
                title: _isArabic(dialogContext)
                    ? 'القائمة الاحتياطية'
                    : 'BACKUP LIST',
                count: backup.length,
                limit: SourcePriorityManager.maxBackupSources,
              ),
              for (final source in backup)
                if (source.stableKey != current.stableKey)
                  ListTile(
                    dense: true,
                    title: Text(source.name),
                    subtitle: Text(
                      _isArabic(dialogContext) ? 'احتياطية' : 'Backup',
                    ),
                    onTap: () => Navigator.pop(dialogContext, source),
                  ),
              if (primary.length + backup.length <= 1)
                Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Text(
                    _isArabic(dialogContext)
                        ? 'أضف سيرفرًا آخر أولًا لتتمكن من التبديل.'
                        : 'Add another source first to enable swapping.',
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
    if (replacement == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _isArabic(dialogContext) ? 'تأكيد التبديل' : 'Confirm swap',
        ),
        content: Text(
          _isArabic(dialogContext)
              ? 'هل تريد تبديل ${current.name} مع ${replacement.name}؟ سيتم تبادل موضعيهما حتى لو كانا في قائمتين مختلفتين.'
              : 'Swap ${current.name} with ${replacement.name}? Their positions will be exchanged, even when they belong to different lists.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_isArabic(dialogContext) ? 'تأكيد التبديل' : 'Swap'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final swapped = await _service.swapPrioritySources(
        category,
        current: current,
        replacement: replacement,
      );
      if (!swapped && mounted) {
        _message(
          _isArabic(context)
              ? 'تعذر إكمال التبديل لأن أحد السيرفرات لم يعد موجودًا في القوائم.'
              : 'The swap could not be completed because one source is no longer in the lists.',
        );
      }
      await _refresh(showBusy: false, forceRefresh: false);
    } catch (error) {
      if (mounted) _message('${tr('repository_error')}: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _buildPriorityRepositoriesSection(List<SourceManifest> catalog) {
    final palette = AppPalette.of(context);
    final primary = _prioritySources(
      _priorityCategory,
      catalog,
      SourcePriorityLane.primary,
    );
    final backup = _prioritySources(
      _priorityCategory,
      catalog,
      SourcePriorityLane.backup,
    );
    final primaryCount = _priorityKeys[_priorityCategory]?.length ?? 0;
    final backupCount = _backupKeys[_priorityCategory]?.length ?? 0;
    final arabic = _isArabic(context);
    Widget buildLane(
      SourcePriorityLane lane,
      List<SourceManifest> sources,
      int count,
      int limit,
      String title,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpace.md,
              bottom: AppSpace.xs,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: AppType.kicker.copyWith(color: palette.mutedText),
                  ),
                ),
                Text(
                  '$count/$limit',
                  style: AppType.metadata.copyWith(color: palette.mutedText),
                ),
              ],
            ),
          ),
          if (sources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Text(
                lane == SourcePriorityLane.primary
                    ? (arabic
                          ? 'القائمة الرئيسية فارغة. أضف السيرفرات التي تريد تجربتها أولًا.'
                          : 'The primary list is empty. Add the sources you want tried first.')
                    : (arabic
                          ? 'القائمة الاحتياطية فارغة. ستُجرّب بعد انتهاء القائمة الرئيسية.'
                          : 'The backup list is empty. These sources run after the primary list.'),
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
            )
          else
            for (var index = 0; index < sources.length; index++) ...<Widget>[
              if (index > 0) Divider(height: 1, color: palette.hairline),
              _PrioritySourceTile(
                source: sources[index],
                index: index,
                onMoveUp: _working || index == 0
                    ? null
                    : () => _changePriorityOrder(lane, index, index - 1),
                onMoveDown: _working || index == sources.length - 1
                    ? null
                    : () => _changePriorityOrder(lane, index, index + 2),
                onSwap: _working ? null : () => _swapPriority(sources[index]),
              ),
            ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(
          title: 'REPOSITORIES',
          trailing: Text('${primaryCount + backupCount}/50'),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                arabic
                    ? 'ترتيب السيرفرات هنا هو الذي يحدد ترتيب تجربتها لهذا النوع من المحتوى فقط. يمكنك وضع أي سيرفر في الرئيسية أو الاحتياطية دون الاعتماد على تصنيف Movies / Series / Anime الموجود في المستودع.'
                    : 'The order here determines how sources are tried for this media type. Any catalog source can be placed in either list regardless of its repository Movies / Series / Anime label.',
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
              const SizedBox(height: AppSpace.md),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: SourcePriorityCategory.values
                    .map(
                      (category) => ChoiceChip(
                        label: Text(_categoryTitle(category, arabic: arabic)),
                        selected: _priorityCategory == category,
                        onSelected: _working
                            ? null
                            : (_) =>
                                  setState(() => _priorityCategory = category),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      arabic
                          ? 'الرئيسية: $primaryCount/20 · الاحتياطية: $backupCount/30'
                          : 'Primary: $primaryCount/20 · Backup: $backupCount/30',
                      style: AppType.metadata.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    // Keep this enabled even when both lanes are full so the
                    // dialog can show the red no-empty-slots notice and allow
                    // the user to remove an existing item.
                    onPressed: _working ? null : _addPriority,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(arabic ? 'إضافة' : 'Add'),
                  ),
                ],
              ),
              buildLane(
                SourcePriorityLane.primary,
                primary,
                primaryCount,
                SourcePriorityManager.maxPrimarySources,
                arabic ? 'القائمة الرئيسية' : 'PRIMARY LIST',
              ),
              Divider(height: AppSpace.xl, color: palette.hairline),
              buildLane(
                SourcePriorityLane.backup,
                backup,
                backupCount,
                SourcePriorityManager.maxBackupSources,
                arabic ? 'القائمة الاحتياطية' : 'BACKUP LIST',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

bool _isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String _categoryTitle(
  SourcePriorityCategory category, {
  required bool arabic,
}) => switch (category) {
  SourcePriorityCategory.movies => arabic ? 'الأفلام' : 'Movies',
  SourcePriorityCategory.series => arabic ? 'المسلسلات' : 'Series',
  SourcePriorityCategory.anime => arabic ? 'الأنمي' : 'Anime',
};

class _PrioritySourceTile extends StatelessWidget {
  const _PrioritySourceTile({
    required this.source,
    required this.index,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onSwap,
  });

  final SourceManifest source;
  final int index;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final status = SourcePriorityPolicy.statusLabel(source);
    final repo = Uri.tryParse(source.repositoryUrl ?? '');
    final repositoryName = repo == null
        ? 'Local'
        : '${repo.host}${repo.path.split('/').take(3).join('/')}';
    final arabic = _isArabic(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.page,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: AppType.metadata.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$repositoryName · ${source.language}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.metadata.copyWith(color: palette.mutedText),
                ),
                Text(
                  status,
                  style: AppType.metadata.copyWith(
                    color:
                        status == 'Beta' ||
                            status == 'Slow' ||
                            status == 'Unrated'
                        ? palette.mutedText
                        : palette.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: arabic ? 'تحريك لأعلى' : 'Move up',
            onPressed: onMoveUp,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            tooltip: arabic ? 'تحريك لأسفل' : 'Move down',
            onPressed: onMoveDown,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          IconButton(
            tooltip: arabic ? 'تبديل مع سيرفر آخر' : 'Swap with another source',
            onPressed: onSwap,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
    );
  }
}

class _SwapListHeading extends StatelessWidget {
  const _SwapListHeading({
    required this.title,
    required this.count,
    required this.limit,
  });

  final String title;
  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: AppType.kicker.copyWith(color: palette.mutedText),
            ),
          ),
          Text(
            '$count/$limit',
            style: AppType.metadata.copyWith(color: palette.mutedText),
          ),
        ],
      ),
    );
  }
}

String _safeRepositoryDisplayUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return 'Repository';
  // Repository tokens should never be echoed into the UI. The functional URL
  // remains untouched in service storage; only its display form is redacted.
  return uri.replace(userInfo: '', query: '', fragment: '').toString();
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.description,
    required this.installedCount,
    required this.catalogCount,
    required this.unsupportedCount,
  });

  final String description;
  final int installedCount;
  final int catalogCount;
  final int unsupportedCount;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            description,
            style: AppType.body.copyWith(color: palette.mutedText),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: <Widget>[
              _CountChip(label: tr('installed_sources'), count: installedCount),
              _CountChip(label: tr('source_catalog'), count: catalogCount),
              if (unsupportedCount > 0)
                _CountChip(
                  label: tr('unsupported_installed'),
                  count: unsupportedCount,
                  warning: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    this.warning = false,
  });
  final String label;
  final int count;
  final bool warning;

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: warning
        ? const Icon(Icons.warning_amber_rounded, size: 16)
        : const Icon(Icons.check_circle_outline_rounded, size: 16),
    label: Text('$label: $count'),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, AppSpace.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppType.kicker.copyWith(color: palette.mutedText),
            ),
          ),
          if (trailing != null)
            DefaultTextStyle(
              style: AppType.metadata.copyWith(color: palette.mutedText),
              child: trailing!,
            ),
        ],
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _RepositoryTile extends StatelessWidget {
  const _RepositoryTile({
    required this.url,
    required this.onRemove,
    required this.onPreview,
    required this.onRollback,
    required this.onPin,
    required this.onClearPin,
    required this.revisionCount,
    required this.isGitHubRaw,
    required this.showDivider,
    this.latestRevision,
    this.pinnedCommit,
    this.error,
  });

  final String url;
  final String? error;
  final String? pinnedCommit;
  final SourceRepositoryRevision? latestRevision;
  final int revisionCount;
  final bool isGitHubRaw;
  final VoidCallback onRemove;
  final VoidCallback onPreview;
  final VoidCallback onRollback;
  final VoidCallback onPin;
  final VoidCallback onClearPin;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final revisionLabel = latestRevision == null
        ? tr('repository_no_revision_saved')
        : <String>[
            '${tr('repository_versions_saved')}: $revisionCount',
            '${tr('repository_http_status')}: ${latestRevision!.statusCode}',
            if (latestRevision!.versionRef != null)
              '${tr('repository_reference')}: ${latestRevision!.versionRef}',
            'SHA-256: ${latestRevision!.contentHash.substring(0, 12)}',
            '${tr('repository_last_validated')}: ${latestRevision!.lastValidatedAt.toLocal().toIso8601String().replaceFirst('T', ' ').split('.').first}',
          ].join(' • ');
    return Column(
      children: <Widget>[
        ListTile(
          dense: true,
          leading: Icon(
            error == null
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            color: error == null
                ? palette.mutedText
                : Theme.of(context).colorScheme.error,
          ),
          title: Text(
            _safeRepositoryDisplayUrl(url),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                error ?? revisionLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (pinnedCommit != null)
                Text(
                  '${tr('repository_pinned_commit')}: ${pinnedCommit!.substring(0, 12)}…',
                  style: AppType.metadata.copyWith(color: palette.mutedText),
                ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            tooltip: tr('repository_actions'),
            onSelected: (value) {
              switch (value) {
                case 'preview':
                  onPreview();
                  break;
                case 'rollback':
                  onRollback();
                  break;
                case 'pin':
                  onPin();
                  break;
                case 'clear_pin':
                  onClearPin();
                  break;
                case 'remove':
                  onRemove();
                  break;
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'preview',
                child: Text(tr('repository_preview_update')),
              ),
              if (revisionCount > 1)
                PopupMenuItem(
                  value: 'rollback',
                  child: Text(tr('repository_rollback')),
                ),
              if (isGitHubRaw && pinnedCommit == null)
                PopupMenuItem(
                  value: 'pin',
                  child: Text(tr('repository_pin_commit')),
                ),
              if (pinnedCommit != null)
                PopupMenuItem(
                  value: 'clear_pin',
                  child: Text(tr('repository_clear_pin')),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'remove',
                child: Text(tr('remove_repository')),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _MangaRepositoryTile extends StatelessWidget {
  const _MangaRepositoryTile({
    required this.url,
    required this.onEdit,
    required this.onRemove,
    required this.showDivider,
  });

  final String url;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final uri = Uri.tryParse(url);
    final label = uri?.host.contains('githubusercontent.com') == true
        ? 'Keiyoushi / Mihon'
        : uri?.host ?? tr('manga_repository_custom');
    return Column(
      children: <Widget>[
        ListTile(
          dense: true,
          leading: Icon(Icons.menu_book_outlined, color: palette.mutedText),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SelectableText(
                url,
                style: AppType.metadata.copyWith(color: palette.secondaryText),
              ),
              const SizedBox(height: 3),
              Text(
                'Mihon · Protobuf index',
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            tooltip: tr('repository_actions'),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'edit',
                child: Text(tr('manga_repository_edit')),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text(tr('remove_repository')),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _DiffCountRow extends StatelessWidget {
  const _DiffCountRow({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text('$count', style: AppType.metadata),
      ],
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.installed,
    required this.supported,
    required this.onChanged,
    required this.onProvenance,
    required this.showDivider,
    this.onSettings,
    this.onConfigure,
    this.configurable = false,
    this.configurationRequired = false,
  });

  final SourceManifest source;
  final bool installed;
  final bool supported;
  final ValueChanged<bool> onChanged;
  final VoidCallback onProvenance;
  final bool showDivider;
  final VoidCallback? onSettings;
  final VoidCallback? onConfigure;
  final bool configurable;
  final bool configurationRequired;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final engineLabel = source.engine.rawType.isEmpty
        ? source.engine.kind.name
        : source.engine.rawType;
    final authorSummary = source.authors.isEmpty
        ? ''
        : ' • ${source.authors.take(2).join(', ')}';
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
          child: Row(
            children: <Widget>[
              if (source.iconUrl != null && source.iconUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(
                    source.iconUrl!,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _sourceIcon(context),
                  ),
                )
              else
                _sourceIcon(context),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(source.name, style: AppType.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      '$engineLabel • ${source.language} • v${source.version}$authorSummary',
                      style: AppType.metadata.copyWith(
                        color: palette.mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (source.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        source.description,
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpace.xs),
                    Wrap(
                      spacing: AppSpace.xs,
                      runSpacing: AppSpace.xs,
                      children: <Widget>[
                        _SourceStatusChip(
                          label: supported
                              ? tr('supported_engine')
                              : tr('unsupported_engine'),
                          warning: !supported,
                        ),
                        if (source.status == 2)
                          _SourceStatusChip(label: tr('source_slow')),
                        if (source.status == 3)
                          _SourceStatusChip(label: tr('source_beta')),
                        if (configurable || configurationRequired)
                          _SourceStatusChip(
                            label: configurationRequired
                                ? tr('stremio_configuration_required')
                                : tr('stremio_configuration_optional'),
                            warning: configurationRequired,
                          ),
                        if (source.isNsfw)
                          _SourceStatusChip(
                            label: tr('source_adult'),
                            warning: true,
                          ),
                        if (source.declaredNsfw == null &&
                            source.engine.kind == SourceEngineKind.javascript)
                          _SourceStatusChip(
                            label: tr('source_safety_undeclared'),
                            warning: true,
                          ),
                        if (source.requiresLiveTvAdapter)
                          _SourceStatusChip(label: tr('live_tv')),
                        if (source.isArchiveCatalog)
                          _SourceStatusChip(label: tr('source_archive_vod')),
                        if (source.engine.config['requiresCredentialReview'] ==
                            true)
                          _SourceStatusChip(
                            label: tr('source_credentials_required'),
                            warning: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              IconButton(
                tooltip: tr('source_provenance'),
                onPressed: onProvenance,
                icon: const Icon(Icons.info_outline_rounded),
              ),
              if (onSettings != null)
                IconButton(
                  tooltip: tr('quickjs_source_settings'),
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
              if (onConfigure != null)
                IconButton(
                  tooltip: tr('open_stremio_configuration'),
                  onPressed: onConfigure,
                  icon: const Icon(Icons.open_in_browser_rounded),
                ),
              if (installed)
                IconButton(
                  tooltip: tr('uninstall'),
                  onPressed: () => onChanged(false),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                )
              else
                IconButton(
                  tooltip: supported ? tr('install') : tr('unsupported_engine'),
                  onPressed: supported ? () => onChanged(true) : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  Widget _sourceIcon(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: AppPalette.of(context).idleFill,
      borderRadius: BorderRadius.circular(9),
    ),
    child: const Icon(Icons.extension_outlined),
  );
}

class _ProvenanceRow extends StatelessWidget {
  const _ProvenanceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppType.metadata.copyWith(
            color: AppPalette.of(context).mutedText,
          ),
        ),
        SelectableText(value, style: AppType.body),
      ],
    ),
  );
}

class _SourceStatusChip extends StatelessWidget {
  const _SourceStatusChip({required this.label, this.warning = false});
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: warning
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: .55)
          : AppPalette.of(context).idleFill,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: AppType.metadata),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.label, this.isError = false});
  final String label;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.lg),
    decoration: BoxDecoration(
      color: AppPalette.of(context).surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: Text(
      label,
      style: AppType.body.copyWith(
        color: isError
            ? Theme.of(context).colorScheme.error
            : AppPalette.of(context).mutedText,
      ),
    ),
  );
}
