import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'sync_service.dart';

/// Source d'état réseau (abstraite pour les tests).
abstract interface class NetworkStatusSource {
  Future<bool> isOnline();
  Stream<bool> get onlineChanges;
}

class ConnectivityPlusSource implements NetworkStatusSource {
  ConnectivityPlusSource([Connectivity? c]) : _c = c ?? Connectivity();
  final Connectivity _c;

  static bool _online(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async => _online(await _c.checkConnectivity());

  @override
  Stream<bool> get onlineChanges =>
      _c.onConnectivityChanged.map(_online).distinct();
}

/// Déclenche la synchronisation :
/// - au retour du réseau (en ignorant le backoff) ;
/// - périodiquement tant que l'application est ouverte (backoff respecté).
///
/// Note : « réseau disponible » ne garantit pas l'accès à l'API (portail
/// captif, données épuisées) ; les erreurs sont gérées par [SyncService].
class SyncScheduler {
  SyncScheduler(this._sync, this._network,
      {this.period = const Duration(minutes: 5), this.canSync});

  final SyncService _sync;
  final NetworkStatusSource _network;
  final Duration period;

  /// Garde supplémentaire (ex. utilisateur connecté sans ré-authentification).
  final bool Function()? canSync;

  StreamSubscription<bool>? _sub;
  Timer? _timer;
  bool _wasOnline = false;
  bool _stopped = false;

  Future<void> start() async {
    _stopped = false;
    final online = await _network.isOnline();
    // stop() a pu être appelé pendant l'attente : ne rien démarrer.
    if (_stopped) return;
    _wasOnline = online;
    _sub = _network.onlineChanges.listen((online) {
      if (online && !_wasOnline) _trigger(force: true);
      _wasOnline = online;
    });
    _timer = Timer.periodic(period, (_) {
      if (_wasOnline) _trigger(force: false);
    });
    if (_wasOnline) _trigger(force: true);
  }

  void _trigger({required bool force}) {
    if (canSync != null && !canSync!()) return;
    unawaited(_sync.sync(force: force));
  }

  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }
}
