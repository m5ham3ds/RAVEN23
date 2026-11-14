import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android local notifications for chapter subscriptions on Manga detail pages.
/// RAVEN checks subscriptions when the work is opened or brought back to the
/// foreground; background polling while the process is closed is not provided
/// by this service.
class MangaNotificationService {
  MangaNotificationService._();

  static final MangaNotificationService instance =
      MangaNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    final pending = _initializing;
    if (pending != null) return pending;
    final task = _initializeInternal();
    _initializing = task;
    try {
      await task;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    if (granted == true) return true;
    return await android?.areNotificationsEnabled() ?? false;
  }

  Future<bool> get areNotificationsEnabled async {
    if (!Platform.isAndroid) return false;
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }

  Future<void> showNewChapters({
    required int anilistId,
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) return;
    await initialize();
    if (!await areNotificationsEnabled) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'new_chapters',
        'New chapters',
        channelDescription:
            'Alerts when a subscribed manga or manhwa has new chapters',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      anilistId & 0x7fffffff,
      title,
      body,
      details,
      payload: 'manga:$anilistId',
    );
  }
}
