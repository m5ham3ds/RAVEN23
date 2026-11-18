// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:raven23/design/app_press_feedback.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../manga/mihon/mihon_runtime.dart';
import '../../manga/mihon/mihon_source_browser_screen.dart';
import '../../mobile/widgets/details_parts.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../video_providers/unified/source_manifest.dart';
import '../../video_providers/unified/source_priority_manager.dart';
import '../../video_providers/unified/unified_source_service.dart';
import 'quickjs_source_settings_dialog.dart';
import 'source_health_probe_service.dart';
import 'source_health_session_controller.dart';
import 'source_repositories_screen.dart';

class ServerStatusScreen extends StatefulWidget {
  const ServerStatusScreen({super.key});

  @override
  State<ServerStatusScreen> createState() => _ServerStatusScreenState();
}

class _ServerStatusScreenState extends State<ServerStatusScreen> {
  final SourceHealthSessionController _session =
      SourceHealthSessionController.instance;
  final UnifiedSourceService _sourceService = UnifiedSourceService();
  final MihonRuntimeService _mihonRuntime = MihonRuntimeService.instance;
  bool _removing = false;

  bool get _checkingVideo => _session.isRunning && !_session.videoPhaseComplete;
  bool get _checkingMihon => _session.isRunning && !_session.mihonPhaseComplete;
  bool get _checking => _session.isRunning;
  String? get _videoError => _session.videoError;
  String? get _repositoryWarning => _session.repositoryWarning;
  String? get _mihonError => _session.mihonError;
  int get _videoProgress => _session.videoProgress;
  int get _videoProgressTotal => _session.videoProgressTotal;
  int get _mihonProgress => _session.mihonProgress;
  int get _mihonProgressTotal => _session.mihonProgressTotal;
  List<SourceHealthCheckResult> get _videoResults => _session.videoResults;
  List<SourceHealthCheckResult> get _mihonResults => _session.mihonResults;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    unawaited(_session.initialize().then((_) => _session.ensureStarted()));
  }

  @override
  void dispose() {
    // The app-wide session owns its probe runtime. Popping this route must not
    // cancel an in-progress check or dispose the JavaScript engine.
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _confirmAndRunCheck() async {
    if (_session.isRunning || _removing) return;
    var confirmed = true;
    if (_session.hasResults || _session.hasRun) {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                _isArabic ? 'إعادة فحص المصادر؟' : 'Run health check again?',
              ),
              content: Text(
                _isArabic
                    ? 'سيتم تحديث SOURCE CATALOG بالكامل، وتفعيل كل المصادر غير المصنفة كهنتاي، ثم فحصها واستبدال النتائج الحالية. لن يبدأ فحص جديد تلقائيًا عند مغادرة الصفحة أو العودة إليها.'
                    : 'The complete SOURCE CATALOG will be refreshed, every non-Hentai source will be enabled and tested, and the current results will be replaced. Leaving and reopening this page will not start another check automatically.',
              ),
              actions: <Widget>[
                AppPressFeedback(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(tr('cancel')),
                  ),
                ),
                AppPressFeedback(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(_isArabic ? 'ابدأ الفحص' : 'Start check'),
                  ),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (confirmed) await _session.start(force: true);
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  List<SourceHealthCheckResult> get _problemResults => _session.problemResults;

  Future<void> _openFailedSources() async {
    final failed = _problemResults;
    if (failed.isEmpty || _removing) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppPalette.of(context).surface,
      builder: (_) => _FailedSourcesSheet(
        results: failed,
        onOpen: _openFailedSource,
        onRemove: _removeSelectedSources,
      ),
    );
  }

  Future<void> _openFailedSource(SourceHealthCheckResult result) async {
    final mihonSource = result.mihonSource;
    if (mihonSource != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MihonSourceCatalogScreen(source: mihonSource),
        ),
      );
      return;
    }

    final source = result.videoSource;
    if (source == null || !mounted) return;
    switch (source.engine.kind) {
      case SourceEngineKind.javascript:
        await QuickJsSourceSettingsDialog.show(context, source);
        return;
      case SourceEngineKind.stremio:
        final rawConfigurationUrl = source.engine.config['configurationUrl'];
        final configurationUri = rawConfigurationUrl is String
            ? Uri.tryParse(rawConfigurationUrl)
            : null;
        if (configurationUri != null &&
            (configurationUri.scheme == 'https' ||
                configurationUri.scheme == 'http') &&
            configurationUri.host.isNotEmpty &&
            configurationUri.userInfo.isEmpty) {
          final open = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                _isArabic ? 'إعداد ${source.name}' : 'Configure ${source.name}',
              ),
              content: Text(
                _isArabic
                    ? 'سيتم فتح صفحة إعدادات الإضافة في المتصفح. احفظ التغييرات هناك ثم ارجع إلى RAVEN23 وأعد الفحص.'
                    : 'The add-on configuration page will open in your browser. Save changes there, return to RAVEN23, and run the health check again.',
              ),
              actions: <Widget>[
                AppPressFeedback(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(tr('cancel')),
                  ),
                ),
                AppPressFeedback(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(tr('open')),
                  ),
                ),
              ],
            ),
          );
          if (open == true) {
            try {
              final launched = await launchUrl(
                configurationUri,
                mode: LaunchMode.externalApplication,
              );
              if (!launched && mounted) {
                _message(
                  _isArabic
                      ? 'تعذر فتح صفحة إعدادات الإضافة في المتصفح.'
                      : 'Could not open the add-on configuration page.',
                );
              }
            } catch (_) {
              if (mounted) {
                _message(
                  _isArabic
                      ? 'تعذر فتح صفحة إعدادات الإضافة في المتصفح.'
                      : 'Could not open the add-on configuration page.',
                );
              }
            }
          }
          return;
        }
        break;
      case SourceEngineKind.vidkingDirect:
      case SourceEngineKind.vidkingWebView:
      case SourceEngineKind.webEmbed:
      case SourceEngineKind.animeSite:
      case SourceEngineKind.httpJson:
      case SourceEngineKind.legacyScraperApi:
      case SourceEngineKind.native:
      case SourceEngineKind.unsupported:
        break;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final details = <Widget>[
          _SourceInfoLine(
            label: _isArabic ? 'نوع المحرك' : 'Engine',
            value: source.engine.rawType,
          ),
          _SourceInfoLine(
            label: _isArabic ? 'معرّف المصدر' : 'Source ID',
            value: source.id,
          ),
          _SourceInfoLine(
            label: _isArabic ? 'اللغة' : 'Language',
            value: source.language,
          ),
          if (source.engine.endpoint.isNotEmpty)
            _SourceInfoLine(
              label: _isArabic ? 'نقطة الاتصال' : 'Endpoint',
              value: source.engine.endpoint,
            ),
          if (source.homepage?.isNotEmpty == true)
            _SourceInfoLine(
              label: _isArabic ? 'الموقع' : 'Homepage',
              value: source.homepage!,
            ),
          if (source.repositoryUrl?.isNotEmpty == true)
            _SourceInfoLine(
              label: _isArabic ? 'المستودع' : 'Repository',
              value: source.repositoryUrl!,
            ),
        ];
        return AlertDialog(
          title: Text(source.name),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _isArabic
                        ? 'هذا المصدر يعتمد على إعدادات ثابتة قادمة من ملف المستودع، ولا يوفر محركه الحالي محرر إعدادات محليًا. يمكنك مراجعة بياناته هنا؛ تعديل عنوان الخادم نفسه يتطلب تحديث تعريف المصدر في المستودع.'
                        : 'This source uses fixed settings from its repository manifest and does not expose a local settings editor in its current engine. Review its details here; changing its server endpoint requires updating the source definition in its repository.',
                    style: AppType.body,
                  ),
                  const SizedBox(height: AppSpace.md),
                  ...details,
                ],
              ),
            ),
          ),
          actions: <Widget>[
            AppPressFeedback(
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr('close')),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _removeSelectedSources(
    List<SourceHealthCheckResult> selected,
  ) async {
    if (selected.isEmpty || _removing || !mounted) return false;
    final videoSources = selected
        .map((result) => result.videoSource)
        .whereType<SourceManifest>()
        .toList(growable: false);
    final mihonSources = selected
        .map((result) => result.mihonSource)
        .whereType<MihonSourceInfo>()
        .toList(growable: false);
    final packageNames = mihonSources
        .map((source) => source.packageName.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _isArabic ? 'تأكيد إزالة العناصر المحددة' : 'Confirm removal',
        ),
        content: Text(
          _isArabic
              ? 'سيتم إلغاء تثبيت ${videoSources.length} من سيرفرات الفيديو، وإزالة ${packageNames.length} من إضافات Mihon. إزالة إضافة Mihon تحذف جميع مصادر اللغات التابعة لحزمة الإضافة نفسها. هل تريد المتابعة؟'
              : 'This will uninstall ${videoSources.length} video providers and ${packageNames.length} Mihon extensions. Removing a Mihon extension also removes every language source supplied by that extension package. Continue?',
        ),
        actions: <Widget>[
          AppPressFeedback(
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('cancel')),
            ),
          ),
          AppPressFeedback(
            child: FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_isArabic ? 'إزالة المحدد' : 'Remove selected'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    setState(() => _removing = true);
    final failures = <String>[];
    var removed = 0;
    try {
      for (final source in videoSources) {
        try {
          await _sourceService.uninstallSource(source);
          // Do not leave an uninstalled provider in any of the user's saved
          // primary/backup execution lists.
          for (final category in SourcePriorityCategory.values) {
            for (final lane in SourcePriorityLane.values) {
              await _sourceService.removePrioritySource(
                category,
                source,
                lane: lane,
              );
            }
          }
          removed++;
        } catch (_) {
          failures.add(source.name);
        }
      }
      for (final packageName in packageNames) {
        try {
          await _mihonRuntime.uninstallExtension(packageName);
          removed++;
        } catch (_) {
          failures.add(packageName);
        }
      }
      _session.dropResultsFor(selected);
      if (!mounted) return removed > 0;
      final message = failures.isEmpty
          ? (_isArabic
                ? 'تمت إزالة العناصر المحددة بنجاح.'
                : 'Selected items were removed successfully.')
          : (_isArabic
                ? 'تمت إزالة $removed عناصر، وتعذرت إزالة ${failures.length}.'
                : 'Removed $removed items; ${failures.length} could not be removed.');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return removed > 0;
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final checking = _checking;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: palette.page,
        appBar: PageAppBar(
          title: tr('check_server'),
          contentWidth: 900,
          bottom: TabBar(
            indicatorColor: palette.foreground,
            labelColor: palette.foreground,
            unselectedLabelColor: palette.mutedText,
            tabs: <Widget>[
              Tab(text: tr('provider_health_overview')),
              Tab(text: tr('source_manager')),
            ],
          ),
          actions: <Widget>[
            AppPressFeedback(
              child: IconButton(
                onPressed: checking || _removing ? null : _confirmAndRunCheck,
                tooltip: _isArabic
                    ? 'فحص كامل SOURCE CATALOG'
                    : 'Check the full SOURCE CATALOG',
                icon: Icon(PhosphorIcons.arrowsClockwise()),
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: <Widget>[
            _buildHealthTab(),
            const SourceRepositoriesScreen(embedded: true),
          ],
        ),
        floatingActionButton: _session.canReviewFailures
            ? FloatingActionButton.extended(
                onPressed: _removing ? null : _openFailedSources,
                icon: Icon(PhosphorIcons.warningCircle()),
                label: Text(
                  _isArabic
                      ? 'مراجعة المصادر المتعثرة (${_problemResults.length})'
                      : 'Review failed sources (${_problemResults.length})',
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildHealthTab() {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return RefreshIndicator(
      color: palette.foreground,
      backgroundColor: palette.raisedSurface,
      onRefresh: _confirmAndRunCheck,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverReadableWidth(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                sliver: SliverList.list(
                  children: <Widget>[
                    KickerHeading(
                      tr('provider_health_overview'),
                      padding: EdgeInsetsDirectional.fromSTEB(
                        gutter,
                        AppSpace.md,
                        gutter,
                        AppSpace.xs,
                      ),
                      trailing: Text(
                        '${_videoResults.length}',
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                    ),
                    if (_repositoryWarning != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          AppSpace.xs,
                          gutter,
                          0,
                        ),
                        child: DetailsMessage(message: _repositoryWarning!),
                      ),
                    if (_videoError != null)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        child: DetailsMessage(message: _videoError!),
                      )
                    else if (_checkingVideo && _videoResults.isEmpty)
                      _buildProgressPanel(
                        label: _isArabic
                            ? 'فحص جميع مصادر SOURCE CATALOG…'
                            : 'Checking all SOURCE CATALOG providers…',
                        completed: _videoProgress,
                        total: _videoProgressTotal,
                      )
                    else if (_videoResults.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        child: DetailsMessage(
                          message: _isArabic
                              ? 'لم يتم العثور على مصادر في SOURCE CATALOG بالمستودعات الحالية.'
                              : 'No providers were found in SOURCE CATALOG for the current repositories.',
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildSummary(_videoResults),
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              _isArabic
                                  ? 'تم تفعيل ${_session.activatedCatalogSourceCount} مصدر آمن للفحص · تم استبعاد ${_session.excludedHentaiSourceCount} مصدر هنتاي'
                                  : '${_session.activatedCatalogSourceCount} safe catalog sources enabled for testing · ${_session.excludedHentaiSourceCount} Hentai sources excluded',
                              style: AppType.metadata.copyWith(
                                color: palette.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_videoResults.isNotEmpty)
                SliverList.builder(
                  itemCount: _videoResults.length,
                  itemBuilder: (context, index) =>
                      _buildSourceRow(_videoResults[index]),
                ),
              if (_checkingVideo && _videoResults.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildProgressPanel(
                    label: _isArabic
                        ? 'يتم فحص بقية السيرفرات…'
                        : 'Checking remaining providers…',
                    completed: _videoProgress,
                    total: _videoProgressTotal,
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.only(top: AppSpace.xxl),
                sliver: SliverList.list(
                  children: <Widget>[
                    KickerHeading(
                      'MIHON SOURCE HEALTH',
                      padding: EdgeInsetsDirectional.fromSTEB(
                        gutter,
                        0,
                        gutter,
                        AppSpace.xs,
                      ),
                      trailing: Text(
                        '${_mihonResults.length}',
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: Text(
                        _isArabic
                            ? 'يتم اختبار كل مصدر Mihon مثبت عبر بحث فعلي بالحرف M، من دون ربط الاختبار بمانغا أو مانهوا محددة.'
                            : 'Each installed Mihon source is tested with a real search for the letter M, without depending on a specific manga or manhwa title.',
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                    ),
                    if (_mihonError != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          AppSpace.sm,
                          gutter,
                          0,
                        ),
                        child: DetailsMessage(message: _mihonError!),
                      )
                    else if (_checkingMihon && _mihonResults.isEmpty)
                      _buildProgressPanel(
                        label: _isArabic
                            ? 'فحص مصادر Mihon المثبتة…'
                            : 'Checking installed Mihon sources…',
                        completed: _mihonProgress,
                        total: _mihonProgressTotal,
                      )
                    else if (_mihonResults.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        child: DetailsMessage(
                          message: _isArabic
                              ? 'لا توجد مصادر Mihon مثبتة حاليًا.'
                              : 'No Mihon sources are currently installed.',
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          AppSpace.md,
                          gutter,
                          AppSpace.xs,
                        ),
                        child: _buildSummary(_mihonResults),
                      ),
                  ],
                ),
              ),
              if (_mihonResults.isNotEmpty)
                SliverList.builder(
                  itemCount: _mihonResults.length,
                  itemBuilder: (context, index) =>
                      _buildSourceRow(_mihonResults[index]),
                ),
              if (_checkingMihon && _mihonResults.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildProgressPanel(
                    label: _isArabic
                        ? 'يتم فحص بقية مصادر Mihon…'
                        : 'Checking remaining Mihon sources…',
                    completed: _mihonProgress,
                    total: _mihonProgressTotal,
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      AppSpace.xxxl + 76 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPanel({
    required String label,
    required int completed,
    required int total,
  }) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter(context),
        AppSpace.md,
        AppSpace.gutter(context),
        AppSpace.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                total == 0 ? label : '$label $completed/$total',
                style: AppType.body.copyWith(color: palette.foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<SourceHealthCheckResult> results) {
    final online = results.where((result) => result.isOnline).length;
    final attention = results.where((result) => result.needsAttention).length;
    final unsupported = results
        .where((result) => result.status == SourceHealthStatus.unsupported)
        .length;
    final pending = results.where((result) => result.isChecking).length;
    final tested = online + attention;
    final percent = pending > 0
        ? ((results.length - pending) / results.length * 100).round()
        : (tested == 0 ? 0 : (online / tested * 100).round());
    final progressValue = pending > 0
        ? (results.length - pending) / results.length
        : (tested == 0 ? 0.0 : online / tested);
    final palette = AppPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    final allResponding = attention == 0 && tested > 0;
    final status = pending > 0
        ? (_isArabic ? 'جارٍ فحص المصادر…' : 'Source checks in progress…')
        : tested == 0
        ? (_isArabic
              ? 'لا توجد اختبارات مدعومة لهذا النوع'
              : 'No supported checks ran')
        : allResponding
        ? (_isArabic
              ? 'جميع المصادر المختبرة تستجيب'
              : 'All tested sources are responding')
        : (_isArabic
              ? 'بعض المصادر تحتاج إلى معالجة'
              : 'Some sources need attention');
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox.square(
                dimension: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 60,
                      child: CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        color: pending > 0
                            ? palette.foreground
                            : (attention > 0 ? error : palette.foreground),
                        backgroundColor: palette.idleFill,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: AppType.cardTitle.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      status,
                      style: AppType.sectionHeader.copyWith(
                        color: attention > 0 ? error : palette.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      _isArabic
                          ? '$online يستجيب · $attention يحتاج إلى معالجة · $pending جارٍ فحصه · $unsupported غير مدعوم'
                          : '$online responding · $attention need attention · $pending checking · $unsupported unsupported',
                      style: AppType.metadata.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMetric(
                  _isArabic ? 'يستجيب' : 'Responding',
                  online,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _buildMetric(
                  _isArabic ? 'مشكلات' : 'Issues',
                  attention,
                  warn: attention > 0,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _buildMetric(
                  _isArabic ? 'الإجمالي' : 'Total',
                  results.length,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, int value, {bool warn = false}) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: palette.idleFill,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '$value',
            style: AppType.sectionHeader.copyWith(
              color: warn
                  ? Theme.of(context).colorScheme.error
                  : palette.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.metadata.copyWith(color: palette.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRow(SourceHealthCheckResult result) {
    final palette = AppPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    final isGood = result.isOnline;
    final isAttention = result.status == SourceHealthStatus.attention;
    final isUnsupported = result.status == SourceHealthStatus.unsupported;
    final isChecking = result.isChecking;
    final color = isGood
        ? palette.secondaryText
        : (isAttention || isUnsupported || isChecking)
        ? palette.mutedText
        : error;
    final subtitleParts = <String>[
      result.engineLabel,
      _reasonLabel(result),
      if (!isChecking) '${result.elapsed.inMilliseconds} ms',
      if (result.resultCount != null)
        _isArabic
            ? '${result.resultCount} نتيجة'
            : '${result.resultCount} results',
      if (result.extractedStreamCount > 0)
        _isArabic
            ? '${result.extractedStreamCount} رابط تشغيل مستخرج'
            : '${result.extractedStreamCount} streams extracted',
      if (result.qualityLabels.isNotEmpty)
        _isArabic
            ? 'الجودات: ${result.qualityLabels.join('، ')}'
            : 'Qualities: ${result.qualityLabels.join(', ')}',
      if (result.httpStatusCode != null) 'HTTP ${result.httpStatusCode}',
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.hairline)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 2,
          ),
          leading: isChecking
              ? SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.foreground,
                  ),
                )
              : Icon(
                  isGood
                      ? PhosphorIcons.checkCircle()
                      : isAttention
                      ? PhosphorIcons.warningCircle()
                      : isUnsupported
                      ? PhosphorIcons.info()
                      : PhosphorIcons.xCircle(),
                  color: color,
                ),
          title: Text(
            result.name,
            style: AppType.body.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitleParts.join(' · '),
            style: AppType.metadata.copyWith(color: palette.mutedText),
          ),
          trailing: Text(
            _statusLabel(result),
            style: AppType.metadata.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          isThreeLine: true,
        ),
      ),
    );
  }

  String _statusLabel(
    SourceHealthCheckResult result,
  ) => switch (result.status) {
    SourceHealthStatus.checking => _isArabic ? 'جاري' : 'Checking',
    SourceHealthStatus.healthy =>
      result.extractedStreamCount > 0
          ? (_isArabic ? 'روابط مستخرجة' : 'Streams extracted')
          : (_isArabic ? 'استجاب البحث' : 'Search responds'),
    SourceHealthStatus.reachable =>
      _isArabic ? 'العنوان متاح' : 'Endpoint reachable',
    SourceHealthStatus.attention => _isArabic ? 'يحتاج معالجة' : 'Attention',
    SourceHealthStatus.failed => _isArabic ? 'فشل' : 'Failed',
    SourceHealthStatus.unsupported => _isArabic ? 'غير مدعوم' : 'Unsupported',
  };

  String _reasonLabel(SourceHealthCheckResult result) {
    if (result.isChecking)
      return _isArabic ? 'جارٍ اختبار المصدر الآن' : 'Testing this source now';
    final count = result.resultCount ?? 0;
    final code = result.httpStatusCode;
    return switch (result.reason) {
      SourceHealthReason.searchResponded =>
        _isArabic
            ? 'نجح البحث بالحرف M وأعاد $count نتيجة؛ لم تُختبر روابط تشغيل'
            : 'M search responded with $count results; no stream URL was tested',
      SourceHealthReason.streamsExtracted =>
        _isArabic
            ? 'استخراج ${result.extractedStreamCount} رابط تشغيل صالح؛ الجودات: ${result.qualityLabels.isEmpty ? 'غير معلومة' : result.qualityLabels.join('، ')}'
            : 'Extracted ${result.extractedStreamCount} valid stream URLs; qualities: ${result.qualityLabels.isEmpty ? 'unknown' : result.qualityLabels.join(', ')}',
      SourceHealthReason.streamExtractionFailed =>
        _isArabic
            ? 'استجاب البحث لكن تعذر استخراج رابط تشغيل صالح من العينة'
            : 'Search responded, but no valid sample stream URL could be extracted',
      SourceHealthReason.endpointResponded =>
        _isArabic
            ? 'استجاب عنوان الخدمة؛ لم يتم اختبار استخراج الفيديو'
            : 'Endpoint responded; stream extraction was not tested',
      SourceHealthReason.apiRequiresMedia =>
        _isArabic
            ? 'واجهة API تستجيب لكنها تتطلب بيانات عمل لاختبار الاستخراج'
            : 'API responded; a media ID is required to test extraction',
      SourceHealthReason.cloudflare =>
        _isArabic
            ? 'تتطلب الخدمة اجتياز تحقق Cloudflare'
            : 'Cloudflare verification is required',
      SourceHealthReason.configurationRequired =>
        _isArabic
            ? 'يجب إكمال إعدادات المصدر أولًا'
            : 'Provider configuration is required',
      SourceHealthReason.networkUnavailable =>
        _isArabic
            ? 'تعذر الاتصال بالشبكة أو بالخادم'
            : 'Network connection to the server failed',
      SourceHealthReason.dnsFailure =>
        _isArabic
            ? 'تعذر العثور على عنوان الخادم عبر DNS'
            : 'DNS could not resolve the server host',
      SourceHealthReason.timeout =>
        _isArabic
            ? 'انتهت مهلة الاتصال أو استجابة الخادم'
            : 'Connection or server response timed out',
      SourceHealthReason.tlsFailure =>
        _isArabic
            ? 'فشل التحقق من شهادة TLS/SSL'
            : 'TLS/SSL certificate validation failed',
      SourceHealthReason.unauthorized =>
        _isArabic
            ? 'الخادم يطلب بيانات مصادقة (HTTP ${code ?? 401})'
            : 'Server requires authentication (HTTP ${code ?? 401})',
      SourceHealthReason.forbidden =>
        _isArabic
            ? 'الخادم رفض الطلب أو حظره (HTTP ${code ?? 403})'
            : 'Server rejected or blocked the request (HTTP ${code ?? 403})',
      SourceHealthReason.rateLimited =>
        _isArabic
            ? 'الخادم فرض حدًا مؤقتًا للطلبات (HTTP ${code ?? 429})'
            : 'Server rate-limited the request (HTTP ${code ?? 429})',
      SourceHealthReason.pathNotFound =>
        _isArabic
            ? 'المسار غير موجود أو تغيّر (HTTP ${code ?? 404})'
            : 'Endpoint path was not found or has changed (HTTP ${code ?? 404})',
      SourceHealthReason.serverError =>
        _isArabic
            ? 'حدث خطأ داخلي في الخادم (HTTP ${code ?? '5xx'})'
            : 'The remote server returned an internal error (HTTP ${code ?? '5xx'})',
      SourceHealthReason.invalidResponse =>
        _isArabic
            ? 'استجابة الخادم غير صالحة أو لا تطابق صيغة المحرك'
            : 'Server response is invalid or does not match the engine contract',
      SourceHealthReason.invalidEndpoint =>
        _isArabic
            ? 'عنوان الخدمة أو مسارها غير صالح'
            : 'The service URL or endpoint path is invalid',
      SourceHealthReason.sourceMissing =>
        _isArabic
            ? 'المصدر غير موجود داخل الإضافة المحملة'
            : 'The source is no longer registered in the loaded extension',
      SourceHealthReason.extensionFailure =>
        _isArabic
            ? 'الإضافة لا تدعم عملية البحث المطلوبة أو فشل تحميلها'
            : 'The extension does not support the required search operation or failed to load',
      SourceHealthReason.unsupportedEngine =>
        _isArabic
            ? 'نوع المحرك غير مدعوم أو ليس من مصادر الفيديو'
            : 'This engine is unsupported or is not a video source',
      SourceHealthReason.unknown =>
        _isArabic
            ? 'حدث خطأ غير مصنف؛ لم يتم افتراض أن المصدر متوقف بسبب ذلك وحده'
            : 'An unclassified error occurred; the source was not assumed offline for a known reason',
    };
  }
}

class _SourceInfoLine extends StatelessWidget {
  const _SourceInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppType.metadata.copyWith(color: palette.mutedText),
          ),
          SelectableText(value, style: AppType.body),
        ],
      ),
    );
  }
}

class _FailedSourcesSheet extends StatefulWidget {
  const _FailedSourcesSheet({
    required this.results,
    required this.onOpen,
    required this.onRemove,
  });

  final List<SourceHealthCheckResult> results;
  final Future<void> Function(SourceHealthCheckResult) onOpen;
  final Future<bool> Function(List<SourceHealthCheckResult>) onRemove;

  @override
  State<_FailedSourcesSheet> createState() => _FailedSourcesSheetState();
}

class _FailedSourcesSheetState extends State<_FailedSourcesSheet> {
  final Set<String> _selectedKeys = <String>{};
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final selected = widget.results
        .where((result) => _selectedKeys.contains(result.selectionKey))
        .toList(growable: false);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.lg,
                AppSpace.lg,
                AppSpace.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? 'المصادر التي فشل فحصها أو تحتاج معالجة'
                          : 'Failed checks and sources needing attention',
                      style: AppType.sectionHeader,
                    ),
                  ),
                  Text(
                    '${widget.results.length}',
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                itemCount: widget.results.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: palette.hairline),
                itemBuilder: (context, index) {
                  final result = widget.results[index];
                  final isSelected = _selectedKeys.contains(
                    result.selectionKey,
                  );
                  return AppPressFeedback(
                    child: ListTile(
                      onTap: _working ? null : () => widget.onOpen(result),
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: _working
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _selectedKeys.add(result.selectionKey);
                                } else {
                                  _selectedKeys.remove(result.selectionKey);
                                }
                              }),
                      ),
                      title: Text(result.name, style: AppType.body),
                      subtitle: Text(
                        '${result.engineLabel} · ${_sheetReason(context, result)}',
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                      trailing: Icon(
                        PhosphorIcons.notePencil(),
                        color: palette.mutedText,
                        size: 18,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (selected.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg,
                    AppSpace.md,
                    AppSpace.lg,
                    AppSpace.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppPressFeedback(
                      child: FilledButton.icon(
                        onPressed: _working
                            ? null
                            : () async {
                                setState(() => _working = true);
                                try {
                                  final removed = await widget.onRemove(
                                    selected,
                                  );
                                  if (removed && mounted)
                                    Navigator.pop(context);
                                } finally {
                                  if (mounted) setState(() => _working = false);
                                }
                              },
                        icon: _working
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(PhosphorIcons.trash()),
                        label: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'إلغاء تثبيت / إزالة المحدد (${selected.length})'
                              : 'Uninstall / remove selected (${selected.length})',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _sheetReason(BuildContext context, SourceHealthCheckResult result) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return switch (result.reason) {
      SourceHealthReason.cloudflare =>
        arabic ? 'تحقق Cloudflare' : 'Cloudflare verification',
      SourceHealthReason.configurationRequired =>
        arabic ? 'إعداد مطلوب' : 'Configuration required',
      SourceHealthReason.networkUnavailable =>
        arabic ? 'مشكلة شبكة' : 'Network failure',
      SourceHealthReason.dnsFailure => arabic ? 'مشكلة DNS' : 'DNS failure',
      SourceHealthReason.timeout => arabic ? 'انتهاء المهلة' : 'Timeout',
      SourceHealthReason.tlsFailure =>
        arabic ? 'شهادة TLS/SSL' : 'TLS/SSL certificate',
      SourceHealthReason.unauthorized =>
        arabic ? 'يتطلب مصادقة' : 'Authentication required',
      SourceHealthReason.forbidden =>
        arabic ? 'رفض / حظر الطلب' : 'Request forbidden',
      SourceHealthReason.rateLimited => arabic ? 'حد الطلبات' : 'Rate limited',
      SourceHealthReason.pathNotFound =>
        arabic ? 'مسار غير موجود' : 'Path not found',
      SourceHealthReason.serverError =>
        arabic ? 'خطأ في الخادم' : 'Server error',
      SourceHealthReason.invalidResponse =>
        arabic ? 'استجابة غير صالحة' : 'Invalid response',
      SourceHealthReason.invalidEndpoint =>
        arabic ? 'مسار غير صالح' : 'Invalid endpoint',
      SourceHealthReason.sourceMissing =>
        arabic ? 'المصدر غير مسجل' : 'Source not registered',
      SourceHealthReason.extensionFailure =>
        arabic ? 'خطأ في الإضافة' : 'Extension error',
      SourceHealthReason.unsupportedEngine =>
        arabic ? 'محرك غير مدعوم' : 'Unsupported engine',
      SourceHealthReason.unknown => arabic ? 'خطأ غير معروف' : 'Unknown error',
      SourceHealthReason.searchResponded =>
        arabic
            ? 'استجاب البحث دون استخراج رابط'
            : 'Search responded; no stream tested',
      SourceHealthReason.streamsExtracted =>
        arabic ? 'استُخرجت روابط تشغيل' : 'Streams extracted',
      SourceHealthReason.streamExtractionFailed =>
        arabic ? 'فشل استخراج روابط العينة' : 'Sample stream extraction failed',
      SourceHealthReason.endpointResponded =>
        arabic ? 'استجاب العنوان' : 'Endpoint responded',
      SourceHealthReason.apiRequiresMedia =>
        arabic ? 'يتطلب بيانات عمل' : 'Requires media metadata',
    };
  }
}
