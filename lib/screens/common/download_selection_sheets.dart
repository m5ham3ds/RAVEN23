import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:raven23/design/app_press_feedback.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../models/offline_download.dart';
import '../../models/external_subtitles.dart';
import '../../functions/language_names.dart';
import '../../video_providers/common.dart';
import '../../video_providers/names.dart';
import '../../video_providers/quality_catalog.dart';
import 'player/player_sheet_ui.dart';

/// The choices before a download or a manual playback: which provider, then
/// which resolution and audio track. Plain rows in the app's palette, so they follow the
/// theme; opened from the player ([inPlayer]) they take the player's.
abstract final class DownloadSelectionSheets {
  /// Null means cancelled. A result with no track preserves the stream default.
  /// The loading sheet also lets users cancel slow manifest inspection.
  static Future<DownloadAudioSelection?> chooseAudio(
    BuildContext context, {
    required Future<List<OfflineAudioTrack>> tracks,
    bool inPlayer = false,
  }) {
    Widget builder(BuildContext context) =>
        _AudioSelectionSheet(tracks: tracks);
    return inPlayer
        ? showPlayerSheet<DownloadAudioSelection>(
            context: context,
            builder: builder,
          )
        : showAppSheet<DownloadAudioSelection>(context, builder: builder);
  }

  /// After quality selection, let the user choose the subtitle to store with
  /// the download. The stream's default audio is kept automatically by Media3.
  static Future<DownloadSubtitleSelection?> chooseSubtitle(
    BuildContext context, {
    required List<RegularSubtitleLinks> tracks,
    Future<List<ExternalSubtitle>>? externalTracks,
    bool inPlayer = false,
  }) {
    final unique = <RegularSubtitleLinks>[];
    final seenUrls = <String>{};
    for (final track in tracks) {
      final url = track.url?.trim() ?? '';
      if (url.isEmpty || !seenUrls.add(url)) continue;
      unique.add(track);
    }

    Widget buildChoices(
      BuildContext sheetContext,
      List<ExternalSubtitle> external,
    ) {
      final seenExternal = <String>{};
      final choices = <_Choice<DownloadSubtitleSelection>>[
        _Choice(
          value: const DownloadSubtitleSelection(null),
          title: tr('download_no_subtitles'),
          subtitle: '',
          icon: PhosphorIcons.closedCaptioning(),
        ),
        for (final track in unique)
          _Choice(
            value: DownloadSubtitleSelection(track),
            title: languageDisplayName(track.language) == ''
                ? tr('not_available')
                : languageDisplayName(track.language),
            subtitle: track.language == null ? '' : track.language!,
            icon: PhosphorIcons.closedCaptioning(),
          ),
        for (final track in external)
          if (track.url.trim().isNotEmpty && seenExternal.add(track.id))
            _Choice(
              value: DownloadSubtitleSelection.external(track),
              title: '${languageDisplayName(track.language)} · ${track.source}',
              subtitle: [
                if (track.release.trim().isNotEmpty) track.release.trim(),
                track.format.toUpperCase(),
                if (track.isHearingImpaired) 'HI',
              ].join(' · '),
              icon: PhosphorIcons.closedCaptioning(),
            ),
      ];
      return _ChoiceSheet<DownloadSubtitleSelection>(
        title: tr('choose_subtitle_language'),
        subtitle: tr('download_subtitle_description'),
        choices: choices,
      );
    }

    Widget builder(BuildContext sheetContext) {
      final future = externalTracks;
      if (future == null) return buildChoices(sheetContext, const []);
      return FutureBuilder<List<ExternalSubtitle>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return PlayerSheetScaffold(
              title: tr('choose_subtitle_language'),
              subtitle: tr('download_subtitle_description'),
              actions: [
                PlayerSheetAction(
                  icon: PhosphorIcons.x(),
                  tooltip: tr('close'),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return buildChoices(
            sheetContext,
            snapshot.hasError
                ? const <ExternalSubtitle>[]
                : snapshot.data ?? const <ExternalSubtitle>[],
          );
        },
      );
    }

    return inPlayer
        ? showPlayerSheet<DownloadSubtitleSelection>(
            context: context,
            builder: builder,
          )
        : showAppSheet<DownloadSubtitleSelection>(
            context,
            builder: builder,
          );
  }

  static Future<VideoProvider?> showProvider(
    BuildContext context, {
    required List<VideoProvider> providers,
    String? title,
    String? subtitle,
  }) {
    return showAppSheet<VideoProvider>(
      context,
      builder: (context) => _ChoiceSheet<VideoProvider>(
        title: title ?? tr('download_choose_provider'),
        subtitle: subtitle ?? tr('download_choose_provider_description'),
        choices: [
          for (final provider in providers)
            _Choice(
              value: provider,
              title: provider.displayName,
              subtitle: provider.contentDescription,
              icon: PhosphorIcons.hardDrives(),
            ),
        ],
      ),
    );
  }

  /// Shows the same per-server, per-quality catalogue used by the player.
  /// New scan results can be published while the sheet is open, so a user can
  /// pick a cached quality immediately without waiting for remaining sources.
  static Future<QualityCatalogEntry?> showQualityCatalog(
    BuildContext context, {
    required List<QualityCatalogEntry> entries,
    ValueListenable<List<QualityCatalogEntry>>? entriesListenable,
    ValueListenable<bool>? searchingListenable,
  }) {
    Widget buildCatalog(
      BuildContext sheetContext,
      List<QualityCatalogEntry> currentEntries,
      bool searching,
    ) {
      final concreteEntries = PlaybackQualityCatalog.bestPerQuality(
        entries: currentEntries.where(
          (entry) =>
              (!entry.isAdaptive || entry.adaptiveTargetHeight != null) &&
              !_isProviderAutoLabel(entry.qualityLabel),
        ),
      );
      return PlayerSheetScaffold(
        title: tr('download_choose_resolution'),
        subtitle: tr('download_resolution_description'),
        actions: [
          PlayerSheetAction(
            icon: PhosphorIcons.x(),
            tooltip: tr('close'),
            onPressed: () => Navigator.pop(sheetContext),
          ),
        ],
        child: Column(
          children: [
            if (searching)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Expanded(
              child: concreteEntries.isEmpty
                  ? Center(
                      child: searching
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(tr('loading_video_sources')),
                              ],
                            )
                          : Text(
                              'No direct downloadable qualities are available.',
                              textAlign: TextAlign.center,
                            ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: concreteEntries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final entry = concreteEntries[index];
                        return PlayerChoiceCard(
                          title: entry.qualityLabel,
                          subtitle: entry.selectionSubtitle,
                          onTap: () => Navigator.pop(sheetContext, entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    }

    Widget buildWithSearchState(
      BuildContext sheetContext,
      List<QualityCatalogEntry> currentEntries,
    ) {
      final listenable = searchingListenable;
      return listenable == null
          ? buildCatalog(sheetContext, currentEntries, false)
          : ValueListenableBuilder<bool>(
              valueListenable: listenable,
              builder: (_, searching, __) =>
                  buildCatalog(sheetContext, currentEntries, searching),
            );
    }

    return showPlayerSheet<QualityCatalogEntry>(
      context: context,
      builder: (sheetContext) {
        final listenable = entriesListenable;
        return listenable == null
            ? buildWithSearchState(sheetContext, entries)
            : ValueListenableBuilder<List<QualityCatalogEntry>>(
                valueListenable: listenable,
                builder: (_, currentEntries, __) =>
                    buildWithSearchState(sheetContext, currentEntries),
              );
      },
    );
  }

  static Future<String?> showResolution(
    BuildContext context, {
    required List<String> resolutions,
    String? providerName,
    Map<String, int?> estimatedSizes = const {},
    ValueListenable<Map<String, int?>>? estimatedSizesListenable,
    bool inPlayer = false,
  }) {
    Widget builder(BuildContext context) {
      final concreteResolutions = resolutions
          .where((resolution) => !_isProviderAutoLabel(resolution))
          .toList(growable: false);
      Widget buildSheet(Map<String, int?> sizes) => _ChoiceSheet<String>(
        title: tr('download_choose_resolution'),
        subtitle: providerName == null
            ? tr('download_resolution_description')
            : tr('download_from_provider', namedArgs: {'name': providerName}),
        choices: [
          for (final resolution in concreteResolutions)
            _Choice(
              value: resolution,
              title: resolution,
              titleDetail: _sizeDescription(sizes, resolution),
              subtitle: _resolutionDescription(resolution),
              icon: PhosphorIcons.monitorPlay(),
            ),
        ],
      );
      final listenable = estimatedSizesListenable;
      return listenable == null
          ? buildSheet(estimatedSizes)
          : ValueListenableBuilder<Map<String, int?>>(
              valueListenable: listenable,
              builder: (_, sizes, __) => buildSheet(sizes),
            );
    }

    return inPlayer
        ? showPlayerSheet<String>(context: context, builder: builder)
        : showAppSheet<String>(context, builder: builder);
  }

  static bool _isProviderAutoLabel(String value) {
    final label = value
        .trim()
        .toLowerCase()
        .split(' · ')
        .first
        .replaceFirst(RegExp(r'\s+\(\d+\)$'), '')
        .trim();
    return RegExp(
      r'^(?:auto(?:matic)?|adaptive|master)(?:\b|$)',
    ).hasMatch(label);
  }

  static String _resolutionDescription(String resolution) {
    final height = int.tryParse(
      RegExp(r'(\d{3,4})').firstMatch(resolution)?.group(1) ?? '',
    );
    if (height == null) return tr('quality_adaptive');
    if (height >= 2160) return tr('quality_uhd');
    if (height >= 1080) return tr('quality_fhd');
    if (height >= 720) return tr('quality_hd');
    return tr('quality_small');
  }

  static String _sizeDescription(
    Map<String, int?> estimatedSizes,
    String resolution,
  ) {
    final bytes = estimatedSizes[resolution];
    return bytes == null ? tr('size_unknown') : '~${_formatBytes(bytes)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}

class DownloadSubtitleSelection {
  const DownloadSubtitleSelection(this.track) : externalTrack = null;

  const DownloadSubtitleSelection.external(this.externalTrack)
      : track = null;

  final RegularSubtitleLinks? track;
  final ExternalSubtitle? externalTrack;
}

class DownloadAudioSelection {
  const DownloadAudioSelection(this.track);

  final OfflineAudioTrack? track;
}

class _AudioSelectionSheet extends StatefulWidget {
  const _AudioSelectionSheet({required this.tracks});

  final Future<List<OfflineAudioTrack>> tracks;

  @override
  State<_AudioSelectionSheet> createState() => _AudioSelectionSheetState();
}

class _AudioSelectionSheetState extends State<_AudioSelectionSheet> {
  List<OfflineAudioTrack>? _tracks;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracks = await widget.tracks;
      if (!mounted) return;
      if (tracks.length <= 1) {
        Navigator.pop(context, DownloadAudioSelection(tracks.firstOrNull));
      } else {
        setState(() => _tracks = tracks);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final tracks = _tracks;
    if (tracks != null) {
      return _ChoiceSheet<DownloadAudioSelection>(
        title: tr('download_choose_audio'),
        subtitle: tr('download_audio_description'),
        choices: [
          for (final track in tracks)
            _Choice(
              value: DownloadAudioSelection(track),
              title: track.name,
              subtitle: '',
              icon: PhosphorIcons.speakerHigh(),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_failed)
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                color: palette.foreground,
                backgroundColor: palette.idleFill,
                minHeight: 3,
              ),
            ),
          const SizedBox(height: AppSpace.md),
          Text(tr(_failed ? 'download_audio_error' : 'download_audio_loading')),
          AppPressFeedback(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice<T> {
  const _Choice({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.titleDetail,
  });

  final T value;
  final String title;
  final String? titleDetail;
  final String subtitle;
  final IconData icon;
}

/// A heading and a list of plain rows: a muted icon, the choice, a detail
/// beside it (a file size), a muted line under it and a chevron.
class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.subtitle,
    required this.choices,
  });

  final String title;
  final String subtitle;
  final List<_Choice<T>> choices;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              gutter,
              AppSpace.md,
              gutter,
              AppSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.sectionHeader.copyWith(
                    fontFamily: AppType.bold,
                    color: palette.foreground,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  subtitle,
                  style: AppType.metadata.copyWith(
                    fontSize: 13,
                    color: palette.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpace.xxl),
              itemCount: choices.length,
              itemBuilder: (context, index) {
                final choice = choices[index];
                return AppPressFeedback(
                  child: InkWell(
                    onTap: () => Navigator.pop(context, choice.value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 60),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          gutter,
                          AppSpace.md,
                          gutter - AppSpace.xs,
                          AppSpace.md,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              choice.icon,
                              size: 22,
                              color: palette.mutedText,
                            ),
                            const SizedBox(width: AppSpace.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          choice.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppType.cardTitle.copyWith(
                                            fontSize: 15,
                                            color: palette.foreground,
                                          ),
                                        ),
                                      ),
                                      if (choice.titleDetail != null) ...[
                                        const SizedBox(width: AppSpace.sm),
                                        Text(
                                          choice.titleDetail!,
                                          maxLines: 1,
                                          style: AppType.metadata.copyWith(
                                            fontSize: 13,
                                            color: palette.secondaryText,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (choice.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      choice.subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.metadata.copyWith(
                                        color: palette.mutedText,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Icon(
                              PhosphorIcons.caretRight(),
                              size: 18,
                              color: palette.mutedText,
                            ),
                          ],
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
