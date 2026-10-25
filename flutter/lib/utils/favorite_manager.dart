import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/film_models.dart';
import 'play_navigation.dart';
import 'server_config_manager.dart';

const String _keyFavorite = 'film_favorite';
const int _maxFavorite = 300;

/// 收藏管理器（按源隔离），对齐 OHOS `FavoriteManager`
class FavoriteManager {
  static final List<VoidCallback> _listeners = [];
  static Map<String, FavoriteItem>? _cachedMap;
  static String _cachedKey = '';
  static final ValueNotifier<int> favoriteVersion = ValueNotifier<int>(0);

  static void onFavoriteChange(VoidCallback cb) {
    if (!_listeners.contains(cb)) {
      _listeners.add(cb);
    }
  }

  static void offFavoriteChange(VoidCallback cb) {
    _listeners.remove(cb);
  }

  static void _notify() {
    favoriteVersion.value++;
    for (final cb in List<VoidCallback>.from(_listeners)) {
      try {
        cb();
      } catch (_) {}
    }
  }

  static bool isFavoriteSync(String id) {
    if (id.isEmpty) return false;
    final map = _cachedMap;
    if (map != null) {
      final currentKey = _dataKey();
      if (_cachedKey == currentKey) {
        if (map.containsKey(id)) return true;
        final split = PlayNavigation.splitLivePlayId(id);
        if (split != null && map.containsKey(split.sid)) return true;
        for (final entry in map.entries) {
          final entrySplit = PlayNavigation.splitLivePlayId(entry.key);
          if (entrySplit != null && entrySplit.sid == id) return true;
        }
      }
    }
    return false;
  }

  static Future<void> preload() async {
    await _readMap();
    favoriteVersion.value++;
  }

  static String _dataKey() {
    return ServerConfigManager.instance.scopedKey(_keyFavorite);
  }

  static Future<bool> isFavorite(String id) async {
    if (id.isEmpty) return false;
    return await find(id) != null;
  }

  static Future<FavoriteItem?> find(String id) async {
    if (id.isEmpty) return null;
    final map = await _readMap();
    return map[id];
  }

  static Future<List<FavoriteItem>> list() async {
    final map = await _readMap();
    final items = map.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static Future<bool> toggle(FavoriteItem item) async {
    final exists = await isFavorite(item.id);
    if (exists) {
      await remove(item.id);
      return false;
    }
    await save(item);
    return true;
  }

  static Future<void> save(FavoriteItem item) async {
    if (item.id.isEmpty) return;
    final map = await _readMap();
    map[item.id] = item;
    final entries = map.values.toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final trimmed = <String, FavoriteItem>{};
    final limit = entries.length > _maxFavorite ? _maxFavorite : entries.length;
    for (var i = 0; i < limit; i++) {
      trimmed[entries[i].id] = entries[i];
    }
    await _writeMap(trimmed);
    _notify();
  }

  static Future<void> remove(String id) async {
    if (id.isEmpty) return;
    final map = await _readMap();
    if (!map.containsKey(id)) return;
    map.remove(id);
    await _writeMap(map);
    _notify();
  }

  static Future<void> clear() async {
    await _writeMap({});
    _notify();
  }

  static Future<Map<String, FavoriteItem>> _readMap() async {
    final key = _dataKey();
    if (key.isEmpty) return {};
    if (_cachedMap != null && _cachedKey == key) {
      return _cachedMap!;
    }
    if (ServerConfigManager.instance.preferences == null) {
      await ServerConfigManager.instance.init();
    }
    try {
      final raw = ServerConfigManager.instance.preferences?.getString(key) ?? '{}';
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final result = <String, FavoriteItem>{};
      parsed.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          result[k] = FavoriteItem.fromJson(v);
        } else if (v is Map) {
          result[k] = FavoriteItem.fromJson(v.map((ik, iv) => MapEntry('$ik', iv)));
        }
      });
      _cachedMap = result;
      _cachedKey = key;
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeMap(Map<String, FavoriteItem> map) async {
    final key = _dataKey();
    _cachedMap = map;
    _cachedKey = key;
    if (key.isEmpty) return;
    if (ServerConfigManager.instance.preferences == null) {
      await ServerConfigManager.instance.init();
    }
    try {
      final data = map.map((k, v) => MapEntry(k, v.toJson()));
      await ServerConfigManager.instance.preferences?.setString(key, jsonEncode(data));
    } catch (_) {}
  }
}
