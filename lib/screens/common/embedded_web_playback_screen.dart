import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../video_providers/unified/source_host_policy.dart';

/// Presents an HTML embedded player in a visible Android WebView.
/// The page receives no JavaScript bridge to the native application.
class EmbeddedWebPlaybackScreen extends StatefulWidget {
  const EmbeddedWebPlaybackScreen({
    required this.url,
    required this.sourceName,
    required this.sourceId,
    this.headers = const <String, String>{},
    this.requiresManualVerification = false,
    this.useTvControls = false,
    super.key,
  });

  final String url;
  final String sourceName;
  final String sourceId;
  final Map<String, String> headers;
  final bool requiresManualVerification;
  final bool useTvControls;

  @override
  State<EmbeddedWebPlaybackScreen> createState() =>
      _EmbeddedWebPlaybackScreenState();
}

class _EmbeddedWebPlaybackScreenState extends State<EmbeddedWebPlaybackScreen> {
  late final Future<void> _validation;
  StreamSubscription<dynamic>? _events;
  MethodChannel? _methods;
  String _status = 'loading';
  bool _canGoBack = false;
  String? _validationError;
  int _viewGeneration = 0;

  @override
  void initState() {
    super.initState();
    _validation = _validateUrl();
    if (widget.requiresManualVerification) {
      _status = 'verification_required';
    }
  }

  Future<void> _validateUrl() async {
    try {
      await const SourceHostPolicy().validate(widget.url);
    } catch (_) {
      _validationError = 'embedded_unsupported_link'.tr();
      _status = 'unsupported_link';
    }
  }

  void _onPlatformViewCreated(int id) {
    _events?.cancel();
    final generation = ++_viewGeneration;
    _methods = MethodChannel('raven23/embedded_web_player/$id');
    _events = EventChannel('raven23/embedded_web_player_events/$id')
        .receiveBroadcastStream()
        .listen(
          (event) {
            if (!mounted || generation != _viewGeneration || event is! Map) {
              return;
            }
            setState(() {
              final nativeStatus = event['status']?.toString() ?? _status;
              _status =
                  widget.requiresManualVerification && nativeStatus == 'loading'
                  ? 'verification_required'
                  : nativeStatus;
              _canGoBack = event['canGoBack'] == true;
            });
          },
          onError: (_) {
            if (!mounted || generation != _viewGeneration) return;
            setState(() => _status = 'failed');
          },
        );
  }

  Future<void> _goBack() async {
    final channel = _methods;
    if (channel != null && _canGoBack) {
      try {
        await channel.invokeMethod<bool>('goBack');
        return;
      } catch (_) {
        // Fall through to route navigation when the platform view has ended.
      }
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _reload() async {
    final channel = _methods;
    if (channel == null) return;
    setState(() => _status = 'loading');
    try {
      await channel.invokeMethod<bool>('reload');
    } catch (_) {
      if (mounted) setState(() => _status = 'failed');
    }
  }

  @override
  void dispose() {
    _viewGeneration++;
    _events?.cancel();
    _methods = null;
    super.dispose();
  }

  String get _statusMessage => switch (_status) {
    'loading' => 'embedded_loading'.tr(),
    'ready' => 'embedded_ready'.tr(),
    'verification_required' => 'embedded_verification_required'.tr(),
    'blocked' => 'embedded_blocked'.tr(),
    'unsupported_link' => 'embedded_unsupported_link'.tr(),
    'failed' => 'embedded_failed'.tr(),
    _ => 'embedded_waiting'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTv = widget.useTvControls;
    return PopScope<Object?>(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _canGoBack) unawaited(_goBack());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            autofocus: isTv,
            tooltip: _canGoBack ? 'player_back'.tr() : 'close'.tr(),
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          title: Text(
            widget.sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: 'embedded_reload'.tr(),
              icon: const Icon(Icons.refresh),
              onPressed: _reload,
            ),
            IconButton(
              tooltip: 'close'.tr(),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        body: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: double.infinity,
              color: _statusColor(theme),
              padding: EdgeInsets.symmetric(
                horizontal: isTv ? 24 : 12,
                vertical: isTv ? 12 : 8,
              ),
              child: Row(
                children: [
                  if (_status == 'loading') ...[
                    SizedBox(
                      width: isTv ? 22 : 16,
                      height: isTv ? 22 : 16,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    Icon(_statusIcon, size: isTv ? 22 : 18),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _validationError ?? _statusMessage,
                      style: TextStyle(fontSize: isTv ? 16 : 13),
                    ),
                  ),
                  if (_status == 'failed' || _status == 'blocked')
                    TextButton(onPressed: _reload, child: Text('retry'.tr())),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<void>(
                future: _validation,
                builder: (context, snapshot) {
                  if (!Platform.isAndroid) {
                    return _EmbeddedUnavailable(
                      message: 'embedded_android_only'.tr(),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_validationError != null) {
                    return _EmbeddedUnavailable(message: _validationError!);
                  }
                  return AndroidView(
                    viewType: 'com.m5ham3ds.raven23/embedded_web_player',
                    creationParams: <String, Object>{
                      'url': widget.url,
                      'sourceId': widget.sourceId,
                      'sourceName': widget.sourceName,
                      'headers': widget.headers,
                    },
                    creationParamsCodec: const StandardMessageCodec(),
                    onPlatformViewCreated: _onPlatformViewCreated,
                  );
                },
              ),
            ),
            if (isTv)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _canGoBack ? _goBack : null,
                      icon: const Icon(Icons.arrow_back),
                      label: Text('player_back'.tr()),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: Text('embedded_reload'.tr()),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                      label: Text('close'.tr()),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ThemeData theme) {
    switch (_status) {
      case 'verification_required':
        return theme.colorScheme.tertiaryContainer;
      case 'blocked':
      case 'unsupported_link':
      case 'failed':
        return theme.colorScheme.errorContainer;
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  IconData get _statusIcon => switch (_status) {
    'ready' => Icons.check_circle_outline,
    'verification_required' => Icons.verified_user_outlined,
    'blocked' => Icons.block,
    'unsupported_link' => Icons.link_off,
    'failed' => Icons.error_outline,
    _ => Icons.info_outline,
  };
}

class _EmbeddedUnavailable extends StatelessWidget {
  const _EmbeddedUnavailable({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
