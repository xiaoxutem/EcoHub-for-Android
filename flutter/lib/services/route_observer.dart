import 'package:flutter/material.dart';
import '../api/http_client.dart';

const _skipRoutes = {
  '/',
  '/play',
  '/search',
  '/filter',
  '/server_config',
};

const _screenNames = {
  '/main': 'IndexPage',
  '/history': 'HistoryPage',
  '/favorite': 'FavoritePage',
  '/tip': 'TipPage',
  '/custom_player': 'CustomPlayerPage',
};

/// 路由观察：埋点 + 栈顶路由名（心跳 / SourceGuard 禁止用 ModalRoute.of）
class EcoHubRouteObserver extends NavigatorObserver {
  static String? currentName;
  static const play = '/play';
  static const serverConfig = '/server_config';
  static const splash = '/';
  static const main = '/main';

  final List<Route<dynamic>> _stack = [];

  void _syncTop() {
    for (var i = _stack.length - 1; i >= 0; i--) {
      final name = _stack[i].settings.name;
      if (name != null && name.isNotEmpty) {
        currentName = name;
        return;
      }
    }
    currentName = null;
  }

  void _report(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty || _skipRoutes.contains(name)) {
      return;
    }
    final page = _screenNames[name] ?? name;
    HttpClient.instance.trackView('browse', '', page);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _stack.add(route);
    _syncTop();
    _report(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _stack.remove(route);
    _syncTop();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _stack.remove(route);
    _syncTop();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      final idx = _stack.indexOf(oldRoute);
      if (idx >= 0) {
        if (newRoute != null) {
          _stack[idx] = newRoute;
        } else {
          _stack.removeAt(idx);
        }
      } else if (newRoute != null) {
        _stack.add(newRoute);
      }
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _syncTop();
    if (newRoute != null) {
      _report(newRoute);
    }
  }
}
