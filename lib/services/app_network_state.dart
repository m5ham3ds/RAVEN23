import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide network-interface changes shared by catalog pages.
///
/// Connectivity events are only a retry signal. They do not prove that the
/// Internet or a specific API is reachable; the page's next request remains
/// the source of truth for success or failure.
class AppNetworkState extends ChangeNotifier {
  AppNetworkState._();

  static final AppNetworkState instance = AppNetworkState._();

  Set<ConnectivityResult> _connections = const <ConnectivityResult>{};
  bool _initialized = false;
  int _revision = 0;

  int get revision => _revision;
  bool get hasNetworkInterface =>
      _connections.any((result) => result != ConnectivityResult.none);

  /// Publishes a system connectivity snapshot.
  ///
  /// [forceNotify] is used when the app resumes. Android may not deliver
  /// connectivity broadcasts to a backgrounded process, so a resume check
  /// must be able to wake failed pages even when the final interface set is
  /// identical to the last foreground snapshot.
  void update(List<ConnectivityResult> results, {bool forceNotify = false}) {
    final next = results.toSet();
    final changed =
        !_initialized ||
        next.length != _connections.length ||
        !next.containsAll(_connections);
    _connections = Set<ConnectivityResult>.unmodifiable(next);
    _initialized = true;
    if (!changed && !forceNotify) return;
    _revision++;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _connections = const <ConnectivityResult>{};
    _initialized = false;
    _revision = 0;
    notifyListeners();
  }
}
