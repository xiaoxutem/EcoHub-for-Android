import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../api/film_api.dart';
import '../models/film_models.dart';
import '../services/route_observer.dart';
import 'server_config_manager.dart';
import 'source_guard.dart';

const int _heartbeatIntervalMs = 10000;
const int _maxFailures = 3;
const int _probeTimeoutMs = 8000;
const int _continueBackoffMs = 60000;

/// 站点前台心跳探活，对齐 OHOS `SiteHeartbeat`
class SiteHeartbeat {
  static final SiteHeartbeat _instance = SiteHeartbeat._internal();
  bool _running = false;
  bool _probing = false;
  Timer? _timer;
  int _consecutiveFailures = 0;
  int _generation = 0;
  bool _configHooked = false;

  factory SiteHeartbeat() => _instance;
  static SiteHeartbeat get instance => _instance;

  SiteHeartbeat._internal();

  void _ensureConfigHook() {
    if (_configHooked) return;
    _configHooked = true;
    FilmApi.onConfigChange(checkSiteClosedState);
  }

  void start() {
    _ensureConfigHook();
    _consecutiveFailures = 0;
    _running = true;
    if (_timer == null && !_probing) {
      _scheduleNext(_heartbeatIntervalMs);
    }
  }

  void stop() {
    _running = false;
    _clearTimer();
  }

  void resetFailures() {
    _consecutiveFailures = 0;
    _generation++;
    _clearTimer();
    if (_running) {
      _scheduleNext(_heartbeatIntervalMs);
    }
  }

  void _clearTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleNext([int delayMs = _heartbeatIntervalMs]) {
    _clearTimer();
    if (!_running) return;
    _timer = Timer(Duration(milliseconds: delayMs), () {
      _timer = null;
      _runProbe();
    });
  }

  /// 只认 `ConnectivityResult.none`，禁止把请求失败当无网。Portal 不做。
  static Future<bool> hasInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty) return false;
      return !results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Future<void> _runProbe() async {
    if (!_running) return;
    if (_probing) {
      _scheduleNext(_heartbeatIntervalMs);
      return;
    }
    final serverUrl = ServerConfigManager.instance.getCachedServerUrl();
    if (serverUrl.isEmpty) return;

    final name = EcoHubRouteObserver.currentName;
    if (name == EcoHubRouteObserver.serverConfig || name == EcoHubRouteObserver.splash) {
      if (_running) {
        _scheduleNext(_heartbeatIntervalMs);
      }
      return;
    }

    final online = await hasInternetConnection();
    if (!online) {
      _consecutiveFailures = 0;
      if (_running) {
        _scheduleNext(_heartbeatIntervalMs);
      }
      return;
    }

    final gen = _generation;
    _probing = true;
    try {
      final config = await FilmApi.getSiteConfig(force: true, timeoutMs: _probeTimeoutMs);
      if (gen != _generation) return;
      _consecutiveFailures = 0;
      checkSiteClosedState(config);
    } catch (_) {
      if (gen != _generation) return;
      final stillOnline = await hasInternetConnection();
      if (!stillOnline || gen != _generation) {
        _consecutiveFailures = 0;
        return;
      }
      _consecutiveFailures++;
      if (_consecutiveFailures >= _maxFailures) {
        SourceGuard.intercept(onContinue: () {
          _consecutiveFailures = 0;
          if (_running) {
            _scheduleNext(_continueBackoffMs);
          }
        });
        return;
      }
    } finally {
      _probing = false;
      if (gen == _generation && _running && _consecutiveFailures < _maxFailures) {
        _scheduleNext(_heartbeatIntervalMs);
      }
    }
  }

  void checkSiteClosedState(BasicConfig config) {
    if (config.state) return;
    final name = EcoHubRouteObserver.currentName;
    if (name == EcoHubRouteObserver.serverConfig ||
        name == EcoHubRouteObserver.splash ||
        name == EcoHubRouteObserver.main) {
      return;
    }
    final nav = SourceGuard.navigatorKey?.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil('/main', (route) => false);
  }
}
