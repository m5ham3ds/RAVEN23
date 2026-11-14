import 'dart:convert';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import 'keiyoushi_extension_repository.dart';
import 'manga_repository_manager.dart';
import 'mihon_runtime.dart';

/// One combined directory for available extensions and their installed
/// Mihon sources. Repository management is available from Check server status > Source repositories.
class MihonSourceBrowserScreen extends StatefulWidget {
  const MihonSourceBrowserScreen({
    this.initialQuery = '',
    this.repository,
    this.repositoryManager,
    this.runtime,
    super.key,
  });

  /// Optional manga title that should be searched after opening a source.
  final String initialQuery;
  final KeiyoushiExtensionRepository? repository;
  final MangaRepositoryManager? repositoryManager;
  final MihonRuntimeService? runtime;

  @override
  State<MihonSourceBrowserScreen> createState() =>
      _MihonSourceBrowserScreenState();
}

class _MihonSourceBrowserScreenState extends State<MihonSourceBrowserScreen> {
  late final KeiyoushiExtensionRepository _repository =
      widget.repository ?? KeiyoushiExtensionRepository();
  late final MangaRepositoryManager _repositoryManager =
      widget.repositoryManager ?? MangaRepositoryManager();
  late final MihonRuntimeService _runtime =
      widget.runtime ?? MihonRuntimeService.instance;
  late final TextEditingController _filterController = TextEditingController();
  final ScrollController _directoryScrollController = ScrollController();
  static const int _directoryPageSize = 10;
  int _visibleEntryCount = _directoryPageSize;
  bool _revealingMoreEntries = false;

  List<MangaExtensionEntry> _extensions = const <MangaExtensionEntry>[];
  List<MihonSourceInfo> _installedSources = const <MihonSourceInfo>[];
  bool _loading = true;
  String? _error;
  String? _busyPackage;

  @override
  void initState() {
    super.initState();
    // Keep the directory itself unfiltered. The requested manga title is
    // forwarded to the source catalogue after the user opens an installed one.
    _directoryScrollController.addListener(_maybeRevealMoreEntries);
    _load();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _directoryScrollController
      ..removeListener(_maybeRevealMoreEntries)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final urls = await _repositoryManager.repositoryUrls();
      final installedSources = await _runtime.listSources(reload: true);
      var failedRepositories = 0;
      final groups = await Future.wait(
        urls.map((url) async {
          try {
            return await _repository.fetchExtensions(repositoryUrl: url);
          } catch (_) {
            failedRepositories++;
            return const <MangaExtensionEntry>[];
          }
        }),
      );

      final seenPackages = <String>{};
      final extensions = <MangaExtensionEntry>[];
      for (final group in groups) {
        for (final extension in group) {
          if (seenPackages.add(extension.packageName)) {
            extensions.add(extension);
          }
        }
      }
      extensions.sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
      if (!mounted) return;
      setState(() {
        _extensions = List<MangaExtensionEntry>.unmodifiable(extensions);
        _installedSources = List<MihonSourceInfo>.unmodifiable(
          installedSources,
        );
        _visibleEntryCount = _directoryPageSize;
        _loading = false;
        if (extensions.isEmpty &&
            installedSources.isEmpty &&
            failedRepositories > 0) {
          _error = tr('mihon_sources_failed');
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<_MihonDirectoryEntry> get _directoryEntries {
    final remainingByPackage = <String, List<MihonSourceInfo>>{};
    for (final source in _installedSources) {
      final key = source.packageName.trim().isEmpty
          ? 'source:${source.id}'
          : source.packageName;
      remainingByPackage
          .putIfAbsent(key, () => <MihonSourceInfo>[])
          .add(source);
    }

    final entries = <_MihonDirectoryEntry>[];
    for (final extension in _extensions) {
      final installed =
          remainingByPackage.remove(extension.packageName) ??
          const <MihonSourceInfo>[];
      entries.add(
        _MihonDirectoryEntry(
          name: extension.name,
          packageName: extension.packageName,
          version: extension.version.isNotEmpty
              ? extension.version
              : installed.isEmpty
              ? ''
              : installed.first.version,
          languages: extension.languages.isNotEmpty
              ? extension.languages
              : installed.map((source) => source.lang).toList(),
          isNsfw: extension.isNsfw || installed.any((source) => source.isNsfw),
          extension: extension,
          installedSources: installed,
        ),
      );
    }

    // Keep installed sources visible even when their extension has disappeared
    // from the currently configured repository index.
    for (final sources in remainingByPackage.values) {
      for (final source in sources) {
        entries.add(
          _MihonDirectoryEntry(
            name: source.name,
            packageName: source.packageName,
            version: source.version,
            languages: <String>[source.lang],
            isNsfw: source.isNsfw,
            installedSources: <MihonSourceInfo>[source],
          ),
        );
      }
    }
    entries.sort((left, right) {
      if (left.isInstalled != right.isInstalled) {
        return left.isInstalled ? -1 : 1;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return entries;
  }

  List<_MihonDirectoryEntry> _filteredEntries() {
    final query = _filterController.text.trim().toLowerCase();
    final entries = _directoryEntries
        .where((entry) {
          if (query.isEmpty) return true;
          return entry.name.toLowerCase().contains(query) ||
              entry.packageName.toLowerCase().contains(query) ||
              entry.languages.any(
                (language) => language.toLowerCase().contains(query),
              ) ||
              entry.installedSources.any(
                (source) => source.name.toLowerCase().contains(query),
              ) ||
              (entry.extension?.sources.any(
                    (source) =>
                        source.name.toLowerCase().contains(query) ||
                        source.language.toLowerCase().contains(query),
                  ) ??
                  false);
        })
        .toList(growable: false);
    // Pin installed sources before available entries, while retaining the
    // alphabetical order within each group and after every search update.
    entries.sort((left, right) {
      if (left.isInstalled != right.isInstalled) {
        return left.isInstalled ? -1 : 1;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return entries;
  }

  void _maybeRevealMoreEntries() {
    if (!mounted ||
        _revealingMoreEntries ||
        !_directoryScrollController.hasClients) {
      return;
    }
    final position = _directoryScrollController.position;
    if (position.extentAfter > 240) return;
    final total = _filteredEntries().length;
    if (_visibleEntryCount >= total) return;
    _revealingMoreEntries = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visibleEntryCount += _directoryPageSize);
      _revealingMoreEntries = false;
    });
  }

  Future<void> _install(MangaExtensionEntry extension) async {
    if (!extension.canInstall) {
      _message(tr('mihon_install_untrusted_disabled'));
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('mihon_install_warning_title')),
        content: Text(
          tr('mihon_install_warning_body', args: <String>[extension.name]),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('mihon_install_confirm')),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busyPackage = extension.packageName);
    try {
      await _runtime.installExtension(extension);
      final sources = await _runtime.listSources(reload: true);
      if (!mounted) return;
      setState(() {
        _installedSources = List<MihonSourceInfo>.unmodifiable(sources);
        _busyPackage = null;
      });
      _message(tr('mihon_extension_installed', args: <String>[extension.name]));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyPackage = null);
      _message('${tr('mihon_extension_install_failed')}: $error');
    }
  }

  Future<void> _uninstall(String packageName, String displayName) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('mihon_uninstall_title')),
        content: Text(tr('mihon_uninstall_body', args: <String>[displayName])),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('uninstall')),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busyPackage = packageName);
    try {
      await _runtime.uninstallExtension(packageName);
      final sources = await _runtime.listSources(reload: true);
      if (!mounted) return;
      setState(() {
        _installedSources = List<MihonSourceInfo>.unmodifiable(sources);
        _busyPackage = null;
      });
      _message(tr('mihon_extension_uninstalled', args: <String>[displayName]));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyPackage = null);
      _message('${tr('mihon_extension_uninstall_failed')}: $error');
    }
  }

  Future<void> _openWebsite(MangaExtensionEntry extension) async {
    final homeUrl = extension.sources
        .map((source) => source.homeUrl.trim())
        .firstWhere((value) {
          final uri = Uri.tryParse(value);
          return uri != null &&
              (uri.scheme == 'https' || uri.scheme == 'http') &&
              uri.host.isNotEmpty;
        }, orElse: () => KeiyoushiExtensionRepository.projectUrl);
    try {
      final opened = await launchUrl(
        Uri.parse(homeUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) _message(tr('mihon_open_source_browser'));
    } catch (error) {
      if (mounted) _message('${tr('mihon_open_source_browser')}: $error');
    }
  }

  Future<void> _openEntry(_MihonDirectoryEntry entry) async {
    if (entry.installedSources.isEmpty) {
      if (entry.extension != null) {
        await _showEntryDetails(entry);
      }
      return;
    }
    if (entry.installedSources.length == 1) {
      await _pushSource(entry.installedSources.single);
      return;
    }
    final selected = await showModalBottomSheet<MihonSourceInfo>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final palette = AppPalette.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  entry.name,
                  style: AppType.sectionHeader.copyWith(
                    color: palette.foreground,
                  ),
                ),
              ),
              for (final source in entry.installedSources)
                ListTile(
                  title: Text(source.name),
                  subtitle: Text(source.lang.toUpperCase()),
                  trailing: Icon(
                    PhosphorIcons.caretRight(),
                    color: palette.mutedText,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(source),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) await _pushSource(selected);
  }

  Future<void> _pushSource(MihonSourceInfo source) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MihonSourceCatalogScreen(
          source: source,
          initialQuery: widget.initialQuery,
        ),
      ),
    );
    if (mounted) await _loadInstalledSourcesOnly();
  }

  Future<void> _loadInstalledSourcesOnly() async {
    try {
      final sources = await _runtime.listSources(reload: true);
      if (!mounted) return;
      setState(
        () => _installedSources = List<MihonSourceInfo>.unmodifiable(sources),
      );
    } catch (_) {
      // Returning from a source catalog should not replace the visible list
      // with an error if the extension's runtime is temporarily unavailable.
    }
  }

  Future<void> _showEntryDetails(_MihonDirectoryEntry entry) async {
    final extension = entry.extension;
    if (!entry.isInstalled && extension == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final palette = AppPalette.of(sheetContext);
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    style: AppType.sectionHeader.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${entry.packageName} · ${entry.version}',
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr('manga_extension_sources'),
                    style: AppType.cardTitle.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (extension != null)
                    for (final source in extension.sources.take(30))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${source.name} · ${source.language}${source.homeUrl.isEmpty ? '' : ' · ${source.homeUrl}'}',
                          style: AppType.metadata.copyWith(
                            color: palette.secondaryText,
                          ),
                        ),
                      )
                  else
                    for (final source in entry.installedSources)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${source.name} · ${source.lang} · ${source.baseUrl}',
                          style: AppType.metadata.copyWith(
                            color: palette.secondaryText,
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  if (entry.isInstalled)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _uninstall(entry.packageName, entry.name);
                      },
                      icon: Icon(PhosphorIcons.trash()),
                      label: Text(tr('uninstall')),
                    )
                  else if (extension != null)
                    FilledButton.icon(
                      onPressed:
                          extension.canInstall &&
                              _runtime.supportsNativeExtensions
                          ? () {
                              Navigator.of(sheetContext).pop();
                              _install(extension);
                            }
                          : null,
                      icon: Icon(PhosphorIcons.downloadSimple()),
                      label: Text(tr('mihon_install_confirm')),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final allEntries = _directoryEntries;
    final entries = _filteredEntries();
    final installedCount = allEntries
        .where((entry) => entry.isInstalled)
        .length;
    final visibleEntries = entries
        .take(_visibleEntryCount)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: palette.page,
        foregroundColor: palette.foreground,
        title: Text(tr('mihon_sources')),
        actions: <Widget>[
          IconButton(
            tooltip: tr('refresh'),
            onPressed: _loading ? null : _load,
            icon: Icon(PhosphorIcons.arrowsClockwise()),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.gutter(context),
          AppSpace.md,
          AppSpace.gutter(context),
          MediaQuery.paddingOf(context).bottom + AppSpace.md,
        ),
        child: Column(
          children: <Widget>[
            Card(
              color: palette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          PhosphorIcons.bookOpenText(),
                          size: 22,
                          color: palette.foreground,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          'Mihon · Protobuf',
                          style: AppType.cardTitle.copyWith(
                            color: palette.foreground,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$installedCount / ${allEntries.length}',
                          style: AppType.metadata.copyWith(
                            color: palette.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loading
                          ? tr('manga_repository_loading')
                          : '${_extensions.length} ${tr('manga_extensions_found')}',
                      style: AppType.metadata.copyWith(
                        color: palette.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('manga_repository_manage_hint'),
                      style: AppType.metadata.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _filterController,
              onChanged: (_) => setState(() {
                _visibleEntryCount = _directoryPageSize;
              }),
              decoration: InputDecoration(
                hintText: tr('search_extensions'),
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                suffixIcon: _filterController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr('clear'),
                        onPressed: () {
                          _filterController.clear();
                          setState(() {});
                        },
                        icon: Icon(PhosphorIcons.x()),
                      ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && entries.isEmpty
                  ? _MihonEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: tr('mihon_sources_failed'),
                      message: _error!,
                      onRetry: _load,
                    )
                  : entries.isEmpty && allEntries.isNotEmpty
                  ? _MihonEmptyState(
                      icon: Icons.search_off_rounded,
                      title: tr('no_extensions_found'),
                      message: tr('search_extensions'),
                      onRetry: () {
                        _filterController.clear();
                        setState(() {});
                      },
                    )
                  : entries.isEmpty
                  ? _MihonEmptyState(
                      icon: Icons.extension_off_outlined,
                      title: tr('mihon_no_installed_sources'),
                      message: tr('mihon_install_from_sources_hint'),
                      onRetry: _load,
                    )
                  : ListView.separated(
                      controller: _directoryScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: visibleEntries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = visibleEntries[index];
                        final isBusy = _busyPackage == entry.packageName;
                        return _MihonDirectoryEntryCard(
                          entry: entry,
                          busy: isBusy,
                          canInstall:
                              entry.extension?.canInstall == true &&
                              _runtime.supportsNativeExtensions,
                          onOpen: () => _openEntry(entry),
                          onWebsite: entry.extension == null
                              ? null
                              : () => _openWebsite(entry.extension!),
                          onInstall: entry.extension == null
                              ? null
                              : () => _install(entry.extension!),
                          onDetails:
                              entry.isInstalled || entry.extension != null
                              ? () => _showEntryDetails(entry)
                              : null,
                        );
                      },
                    ),
            ),
            if (visibleEntries.length < entries.length)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: Text(
                  '${visibleEntries.length} / ${entries.length}',
                  style: AppType.metadata.copyWith(color: palette.mutedText),
                ),
              ),
            const SizedBox(height: AppSpace.sm),
            Text(
              tr('mihon_extensions_install_note'),
              style: AppType.metadata.copyWith(color: palette.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MihonDirectoryEntry {
  const _MihonDirectoryEntry({
    required this.name,
    required this.packageName,
    required this.version,
    required this.languages,
    required this.isNsfw,
    required this.installedSources,
    this.extension,
  });

  final String name;
  final String packageName;
  final String version;
  final List<String> languages;
  final bool isNsfw;
  final MangaExtensionEntry? extension;
  final List<MihonSourceInfo> installedSources;

  bool get isInstalled => installedSources.isNotEmpty;

  String get subtitle {
    final resolvedLanguages = languages
        .map((language) => language.trim())
        .where((language) => language.isNotEmpty)
        .map((language) => language.toUpperCase())
        .toSet()
        .toList(growable: false);
    final parts = <String>[
      ...resolvedLanguages,
      if (version.trim().isNotEmpty) version.trim(),
      if (isNsfw) '18+',
    ];
    return parts.join(' · ');
  }
}

class _MihonDirectoryEntryCard extends StatelessWidget {
  const _MihonDirectoryEntryCard({
    required this.entry,
    required this.busy,
    required this.canInstall,
    required this.onOpen,
    required this.onWebsite,
    required this.onInstall,
    required this.onDetails,
  });

  final _MihonDirectoryEntry entry;
  final bool busy;
  final bool canInstall;
  final VoidCallback onOpen;
  final VoidCallback? onWebsite;
  final VoidCallback? onInstall;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: entry.isInstalled ? onDetails : null,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.raisedSurface,
                ),
                alignment: Alignment.center,
                child: Icon(
                  PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
                  size: 29,
                  color: palette.foreground,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.cardTitle.copyWith(
                        fontSize: 17,
                        height: 22 / 17,
                        color: palette.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                        fontSize: 14,
                        color: palette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (busy)
                const SizedBox(
                  width: 76,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (entry.isInstalled)
                IconButton(
                  tooltip: tr('open'),
                  onPressed: onOpen,
                  icon: Icon(
                    PhosphorIcons.caretRight(),
                    size: 29,
                    color: palette.foreground,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: tr('mihon_open_source_browser'),
                      onPressed: onWebsite,
                      icon: Icon(
                        PhosphorIcons.globeHemisphereWest(),
                        size: 27,
                        color: palette.foreground,
                      ),
                    ),
                    IconButton(
                      tooltip: entry.extension?.canInstall == true
                          ? tr('mihon_install_confirm')
                          : tr('mihon_install_untrusted_disabled'),
                      onPressed: canInstall ? onInstall : null,
                      icon: Icon(
                        PhosphorIcons.downloadSimple(),
                        size: 27,
                        color: canInstall
                            ? palette.foreground
                            : palette.mutedText,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MihonSourceCatalogScreen extends StatefulWidget {
  const MihonSourceCatalogScreen({
    required this.source,
    this.initialQuery = '',
    super.key,
  });

  final MihonSourceInfo source;
  final String initialQuery;

  @override
  State<MihonSourceCatalogScreen> createState() =>
      _MihonSourceCatalogScreenState();
}

class _MihonSourceCatalogScreenState extends State<MihonSourceCatalogScreen> {
  final MihonRuntimeService _runtime = MihonRuntimeService.instance;
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialQuery,
  );
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  bool _loading = true;
  bool _hasSettings = false;
  String? _error;
  String? _filtersJson;
  String _mode = 'search';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _hasSettings = await _runtime.hasSettings(widget.source.id);
    } catch (_) {
      _hasSettings = false;
    }
    if (!mounted) return;
    if (widget.initialQuery.trim().isNotEmpty) {
      await _search(reset: true);
    } else {
      await _loadPopular();
    }
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<List<Map<String, dynamic>>> Function() task) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await task();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadPopular() {
    _mode = 'popular';
    _page = 1;
    return _run(() => _runtime.popular(widget.source.id));
  }

  Future<void> _loadLatest() {
    _mode = 'latest';
    _page = 1;
    return _run(() => _runtime.latest(widget.source.id));
  }

  Future<void> _search({bool reset = false}) {
    final query = _searchController.text.trim();
    if (query.isEmpty) return _loadPopular();
    _mode = 'search';
    if (reset) _page = 1;
    return _run(
      () => _runtime.search(
        widget.source.id,
        query,
        page: _page,
        filtersJson: _filtersJson,
      ),
    );
  }

  Future<void> _nextPage() async {
    if (_loading) return;
    _page++;
    final previous = _items;
    setState(() => _loading = true);
    try {
      final next = switch (_mode) {
        'latest' => await _runtime.latest(widget.source.id, page: _page),
        'search' => await _runtime.search(
          widget.source.id,
          _searchController.text.trim(),
          page: _page,
          filtersJson: _filtersJson,
        ),
        _ => await _runtime.popular(widget.source.id, page: _page),
      };
      if (!mounted) return;
      setState(() {
        _items = <Map<String, dynamic>>[...previous, ...next];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      _page--;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openFilters() async {
    try {
      final raw = await _runtime.filterList(widget.source.id);
      if (!mounted) return;
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _MihonFiltersSheet(filters: raw),
      );
      if (result != null) {
        _filtersJson = result;
        await _search(reset: true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _solveCloudflare() async {
    final url = widget.source.baseUrl;
    if (url.isEmpty) return;
    try {
      await _runtime.solveCloudflare(url);
      if (!mounted) return;
      await _runtime.clearCache();
      if (_mode == 'search') {
        await _search(reset: true);
      } else if (_mode == 'latest') {
        await _loadLatest();
      } else {
        await _loadPopular();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openSettings() async {
    try {
      await _runtime.openSettings(widget.source.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: palette.page,
        foregroundColor: palette.foreground,
        title: Text(widget.source.name),
        actions: <Widget>[
          if (_hasSettings)
            IconButton(
              tooltip: tr('source_configuration'),
              onPressed: _openSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
          if (widget.source.baseUrl.isNotEmpty)
            IconButton(
              tooltip: tr('mihon_open_source_browser'),
              onPressed: () async {
                try {
                  await _runtime.openSourceWebView(
                    widget.source.baseUrl,
                    title: widget.source.name,
                  );
                } catch (error) {
                  if (!messenger.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              },
              icon: const Icon(Icons.public_rounded),
            ),
          IconButton(
            tooltip: tr('refresh'),
            onPressed: _loading
                ? null
                : () => _mode == 'search'
                      ? _search(reset: true)
                      : _mode == 'latest'
                      ? _loadLatest()
                      : _loadPopular(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.gutter(context),
              AppSpace.md,
              AppSpace.gutter(context),
              AppSpace.sm,
            ),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(reset: true),
                  decoration: InputDecoration(
                    hintText: tr('mihon_search_source'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => _search(reset: true),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Row(
                  children: <Widget>[
                    _ModeChip(
                      label: tr('popular'),
                      active: _mode == 'popular',
                      onTap: _loadPopular,
                    ),
                    const SizedBox(width: 8),
                    _ModeChip(
                      label: tr('latest'),
                      active: _mode == 'latest',
                      onTap: _loadLatest,
                    ),
                    const SizedBox(width: 8),
                    _ModeChip(
                      label: tr('search'),
                      active: _mode == 'search',
                      onTap: () => _search(reset: true),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: tr('mihon_filters'),
                      onPressed: _openFilters,
                      icon: const Icon(Icons.filter_list_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _items.isEmpty
                ? _MihonEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: tr('mihon_source_request_failed'),
                    message: _error!,
                    onRetry: () => _mode == 'search'
                        ? _search(reset: true)
                        : _mode == 'latest'
                        ? _loadLatest()
                        : _loadPopular(),
                    secondaryLabel: tr('mihon_solve_cloudflare'),
                    onSecondary: _solveCloudflare,
                  )
                : _items.isEmpty
                ? Center(child: Text(tr('no_results_found')))
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      AppSpace.gutter(context),
                      AppSpace.sm,
                      AppSpace.gutter(context),
                      MediaQuery.paddingOf(context).bottom + AppSpace.xl,
                    ),
                    itemCount: _items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.md,
                          ),
                          child: Center(
                            child: _loading
                                ? const CircularProgressIndicator()
                                : OutlinedButton.icon(
                                    onPressed: _nextPage,
                                    icon: const Icon(Icons.expand_more_rounded),
                                    label: Text(tr('load_more')),
                                  ),
                          ),
                        );
                      }
                      final item = _items[index];
                      return Card(
                        color: palette.surface,
                        child: ListTile(
                          leading: _MihonCover(
                            sourceId: widget.source.id,
                            url: '${item['thumbnail_url'] ?? ''}',
                            width: 58,
                            height: 82,
                          ),
                          title: Text(
                            '${item['title'] ?? tr('untitled')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item['genre'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => MihonSourceDetailScreen(
                                source: widget.source,
                                manga: item,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MihonSourceDetailScreen extends StatefulWidget {
  const MihonSourceDetailScreen({
    required this.source,
    required this.manga,
    super.key,
  });

  final MihonSourceInfo source;
  final Map<String, dynamic> manga;

  @override
  State<MihonSourceDetailScreen> createState() =>
      _MihonSourceDetailScreenState();
}

class _MihonSourceDetailScreenState extends State<MihonSourceDetailScreen> {
  final MihonRuntimeService _runtime = MihonRuntimeService.instance;
  Map<String, dynamic> _details = const <String, dynamic>{};
  List<Map<String, dynamic>> _chapters = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  String get _url => '${widget.manga['url'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait<Object>(<Future<Object>>[
        _runtime.details(widget.source.id, _url),
        _runtime.chapters(widget.source.id, _url),
      ]);
      if (!mounted) return;
      setState(() {
        _details = responses[0] as Map<String, dynamic>;
        _chapters = responses[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final title = '${_details['title'] ?? widget.manga['title'] ?? ''}';
    final cover =
        '${_details['thumbnail_url'] ?? widget.manga['thumbnail_url'] ?? ''}';
    final description = '${_details['description'] ?? ''}'
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .trim();
    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: palette.page,
        foregroundColor: palette.foreground,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(AppSpace.gutter(context)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MihonCover(
                  sourceId: widget.source.id,
                  url: cover,
                  width: 104,
                  height: 148,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppType.sectionHeader.copyWith(
                          color: palette.foreground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.source.name,
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_details['author'] ?? ''} ${_details['artist'] ?? ''}'
                            .trim(),
                        style: AppType.metadata.copyWith(
                          color: palette.secondaryText,
                        ),
                      ),
                      if (description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(
                            color: palette.secondaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: palette.hairline, height: 1),
          Expanded(
            child: _loading && _chapters.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _chapters.isEmpty
                ? _MihonEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: tr('mihon_chapters_failed'),
                    message: _error!,
                    onRetry: _load,
                    secondaryLabel: tr('mihon_solve_cloudflare'),
                    onSecondary: () async {
                      final url = widget.source.baseUrl;
                      if (url.isNotEmpty) await _runtime.solveCloudflare(url);
                      await _load();
                    },
                  )
                : _chapters.isEmpty
                ? Center(child: Text(tr('mihon_no_chapters')))
                : ListView.separated(
                    itemCount: _chapters.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: palette.hairline),
                    itemBuilder: (context, index) {
                      final chapter = _chapters[index];
                      return ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text('${chapter['name'] ?? tr('chapter')}'),
                        subtitle: Text('${chapter['scanlator'] ?? ''}'),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => MihonChapterReaderScreen(
                              source: widget.source,
                              chapter: chapter,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MihonChapterReaderScreen extends StatefulWidget {
  const MihonChapterReaderScreen({
    required this.source,
    required this.chapter,
    super.key,
  });

  final MihonSourceInfo source;
  final Map<String, dynamic> chapter;

  @override
  State<MihonChapterReaderScreen> createState() =>
      _MihonChapterReaderScreenState();
}

class _MihonChapterReaderScreenState extends State<MihonChapterReaderScreen> {
  final MihonRuntimeService _runtime = MihonRuntimeService.instance;
  List<Map<String, dynamic>> _pages = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pages = await _runtime.pages(
        widget.source.id,
        '${widget.chapter['url'] ?? ''}',
      );
      if (!mounted) return;
      setState(() {
        _pages = pages
            .where((page) => '${page['imageUrl'] ?? ''}'.isNotEmpty)
            .toList(growable: false);
        _loading = false;
        if (_pages.isEmpty) _error = tr('mihon_pages_empty');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.chapter['name'] ?? tr('chapter')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? _MihonEmptyState(
              icon: Icons.image_not_supported_outlined,
              title: tr('mihon_pages_unavailable'),
              message: _error!,
              onRetry: _load,
              secondaryLabel: tr('mihon_solve_cloudflare'),
              onSecondary: () async {
                final url = widget.source.baseUrl;
                if (url.isNotEmpty) await _runtime.solveCloudflare(url);
                await _load();
              },
              dark: true,
            )
          : ListView.builder(
              cacheExtent: 1200,
              itemCount: _pages.length,
              itemBuilder: (context, index) => _MihonPageImage(
                runtime: _runtime,
                sourceId: widget.source.id,
                page: _pages[index],
                index: index,
              ),
            ),
    );
  }
}

class _MihonPageImage extends StatefulWidget {
  const _MihonPageImage({
    required this.runtime,
    required this.sourceId,
    required this.page,
    required this.index,
  });

  final MihonRuntimeService runtime;
  final int sourceId;
  final Map<String, dynamic> page;
  final int index;

  @override
  State<_MihonPageImage> createState() => _MihonPageImageState();
}

class _MihonPageImageState extends State<_MihonPageImage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<Uint8List> _fetch() {
    final rawHeaders = widget.page['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const <String, String>{};
    return widget.runtime.image(
      widget.sourceId,
      '${widget.page['imageUrl']}',
      headers: headers,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Container(
          height: 220,
          color: const Color(0xFF171717),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.broken_image_outlined, color: Colors.white70),
              const SizedBox(height: 8),
              Text(
                tr('mihon_page_failed', args: ['${widget.index + 1}']),
                style: const TextStyle(color: Colors.white70),
              ),
              TextButton(
                onPressed: () => setState(() => _future = _fetch()),
                child: Text(tr('retry')),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return Container(
          height: 320,
          color: const Color(0xFF101010),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white70),
        );
      }
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Image.memory(
          snapshot.data!,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          gaplessPlayback: true,
        ),
      );
    },
  );
}

class _MihonCover extends StatefulWidget {
  const _MihonCover({
    required this.sourceId,
    required this.url,
    required this.width,
    required this.height,
  });

  final int sourceId;
  final String url;
  final double width;
  final double height;

  @override
  State<_MihonCover> createState() => _MihonCoverState();
}

class _MihonCoverState extends State<_MihonCover> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = MihonRuntimeService.instance.image(widget.sourceId, widget.url);
  }

  @override
  void didUpdateWidget(covariant _MihonCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.sourceId != widget.sourceId) {
      _future = MihonRuntimeService.instance.image(widget.sourceId, widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.url.isEmpty
            ? ColoredBox(color: palette.raisedSurface)
            : FutureBuilder<Uint8List>(
                future: _future,
                builder: (context, snapshot) => snapshot.hasData
                    ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                    : ColoredBox(
                        color: palette.raisedSurface,
                        child: const Center(
                          child: Icon(Icons.menu_book_rounded),
                        ),
                      ),
              ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: .18),
      labelStyle: TextStyle(
        color: active ? palette.foreground : palette.secondaryText,
      ),
    );
  }
}

class _MihonEmptyState extends StatelessWidget {
  const _MihonEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
    this.dark = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final foreground = dark ? Colors.white : palette.foreground;
    final secondary = dark ? Colors.white70 : palette.secondaryText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 38, color: secondary),
            const SizedBox(height: AppSpace.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.cardTitle.copyWith(color: foreground),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.metadata.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpace.md),
            OutlinedButton(onPressed: onRetry, child: Text(tr('retry'))),
            if (secondaryLabel != null && onSecondary != null)
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ),
      ),
    );
  }
}

class _MihonFiltersSheet extends StatefulWidget {
  const _MihonFiltersSheet({required this.filters});
  final List<Map<String, dynamic>> filters;

  @override
  State<_MihonFiltersSheet> createState() => _MihonFiltersSheetState();
}

class _MihonFiltersSheetState extends State<_MihonFiltersSheet> {
  late List<Map<String, dynamic>> _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.filters.map(_cloneMap).toList(growable: true);
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> value) =>
      (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();

  Widget _filter(Map<String, dynamic> filter) {
    final type = '${filter['type'] ?? ''}';
    final name = '${filter['name'] ?? ''}';
    switch (type) {
      case 'header':
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.xs),
          child: Text(name, style: AppType.cardTitle),
        );
      case 'separator':
        return const Divider();
      case 'select':
        final values = (filter['values'] as List? ?? const <dynamic>[])
            .map((v) => '$v')
            .toList();
        final selected = (filter['state'] as num?)?.toInt() ?? 0;
        if (values.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: DropdownButtonFormField<int>(
            initialValue: selected.clamp(0, values.length - 1).toInt(),
            decoration: InputDecoration(labelText: name),
            items: <DropdownMenuItem<int>>[
              for (var i = 0; i < values.length; i++)
                DropdownMenuItem<int>(value: i, child: Text(values[i])),
            ],
            onChanged: (value) => setState(() => filter['state'] = value ?? 0),
          ),
        );
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: TextFormField(
            initialValue: '${filter['state'] ?? ''}',
            decoration: InputDecoration(labelText: name),
            onChanged: (value) => filter['state'] = value,
          ),
        );
      case 'checkbox':
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name),
          value: filter['state'] == true,
          onChanged: (value) => setState(() => filter['state'] = value),
        );
      case 'tristate':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: DropdownButtonFormField<int>(
            initialValue: ((filter['state'] as num?)?.toInt() ?? 0)
                .clamp(0, 2)
                .toInt(),
            decoration: InputDecoration(labelText: name),
            items: <DropdownMenuItem<int>>[
              DropdownMenuItem(
                value: 0,
                child: Text(tr('mihon_filter_ignore')),
              ),
              DropdownMenuItem(
                value: 1,
                child: Text(tr('mihon_filter_include')),
              ),
              DropdownMenuItem(
                value: 2,
                child: Text(tr('mihon_filter_exclude')),
              ),
            ],
            onChanged: (value) => setState(() => filter['state'] = value ?? 0),
          ),
        );
      case 'sort':
        final values = (filter['values'] as List? ?? const <dynamic>[])
            .map((v) => '$v')
            .toList();
        final current = filter['state'] is Map
            ? Map<String, dynamic>.from(filter['state'] as Map)
            : <String, dynamic>{'index': 0, 'ascending': false};
        if (values.isEmpty) return const SizedBox.shrink();
        final index = ((current['index'] as num?)?.toInt() ?? 0)
            .clamp(0, values.length - 1)
            .toInt();
        return Column(
          children: <Widget>[
            DropdownButtonFormField<int>(
              initialValue: index,
              decoration: InputDecoration(labelText: name),
              items: <DropdownMenuItem<int>>[
                for (var i = 0; i < values.length; i++)
                  DropdownMenuItem<int>(value: i, child: Text(values[i])),
              ],
              onChanged: (value) => setState(
                () => filter['state'] = <String, dynamic>{
                  'index': value ?? 0,
                  'ascending': current['ascending'] == true,
                },
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('mihon_sort_ascending')),
              value: current['ascending'] == true,
              onChanged: (value) => setState(
                () => filter['state'] = <String, dynamic>{
                  'index': index,
                  'ascending': value,
                },
              ),
            ),
          ],
        );
      case 'group':
        final nestedFilters = filter['filters'] as List? ?? const <dynamic>[];
        final children = nestedFilters
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(growable: false);
        return ExpansionTile(
          title: Text(name),
          children: <Widget>[for (final child in children) _filter(child)],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.gutter(context),
          0,
          AppSpace.gutter(context),
          bottom + AppSpace.md,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: <Widget>[
              Text(tr('mihon_filters'), style: AppType.sectionHeader),
              const SizedBox(height: AppSpace.sm),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    for (final filter in _filters) _filter(filter),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(jsonEncode(_filters)),
                  child: Text(tr('apply_filters')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
