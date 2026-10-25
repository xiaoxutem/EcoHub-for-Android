import 'dart:convert';
import '../models/film_models.dart';
import 'server_config_manager.dart';

const String _keyHistory = 'film_history';
const int _maxHistory = 200;

/// 观看历史记录管理器（按源隔离）
class HistoryManager {
  static String _dataKey() {
    return ServerConfigManager.instance.scopedKey(_keyHistory);
  }

  static Future<HistoryItem?> find(String id) async {
    final map = await _readMap();
    return map[id];
  }

  static Future<List<HistoryItem>> list() async {
    final map = await _readMap();
    final items = map.values.toList();
    items.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
    return items;
  }

  static Future<void> save(HistoryItem item) async {
    final map = await _readMap();
    map[item.id] = item;
    final entries = map.values.toList();
    entries.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));

    final trimmed = <String, HistoryItem>{};
    final limit = entries.length > _maxHistory ? _maxHistory : entries.length;
    for (var i = 0; i < limit; i++) {
      trimmed[entries[i].id] = entries[i];
    }
    await _writeMap(trimmed);
  }

  static Future<void> remove(String id) async {
    final map = await _readMap();
    map.remove(id);
    await _writeMap(map);
  }

  static Future<void> clear() async {
    await _writeMap({});
  }

  /// 对齐 OHOS HistoryManager.migrateLegacy()
  /// 将未作用域化历史或不同协议别名的历史记录迁移到当前作用域
  static Future<void> migrateLegacy() async {
    final key = _dataKey();
    if (key.isEmpty) return;
    var pref = ServerConfigManager.instance.preferences;
    if (pref == null) {
      await ServerConfigManager.instance.init();
      pref = ServerConfigManager.instance.preferences;
    }
    if (pref == null) return;

    final origin = ServerConfigManager.instance.getOrigin().toLowerCase();
    final aliases = <String>[_keyHistory];
    if (origin.isNotEmpty) {
      aliases.add('$_keyHistory@$origin');
      if (origin.startsWith('https://')) {
        aliases.add('$_keyHistory@http://${origin.substring(8)}');
      } else if (origin.startsWith('http://')) {
        aliases.add('$_keyHistory@https://${origin.substring(7)}');
      }
    }

    try {
      var current = pref.getString(key) ?? '';
      for (final alias in aliases) {
        if (alias == key) continue;
        final raw = pref.getString(alias) ?? '';
        if (raw.isEmpty || raw == '{}') continue;
        if (current.isEmpty || current == '{}') {
          await pref.setString(key, raw);
          current = raw;
        }
        await pref.remove(alias);
      }
    } catch (_) {}
  }

  static Future<Map<String, HistoryItem>> _readMap() async {
    final key = _dataKey();
    if (key.isEmpty) return {};
    final pref = ServerConfigManager.instance.preferences;
    if (pref == null) await ServerConfigManager.instance.init();
    try {
      final raw = ServerConfigManager.instance.preferences?.getString(key) ?? '{}';
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final result = <String, HistoryItem>{};
      parsed.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          result[k] = HistoryItem.fromJson(v);
        } else if (v is Map) {
          result[k] = HistoryItem.fromJson(v.map((ik, iv) => MapEntry('$ik', iv)));
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeMap(Map<String, HistoryItem> map) async {
    final key = _dataKey();
    if (key.isEmpty) return;
    final pref = ServerConfigManager.instance.preferences;
    if (pref == null) await ServerConfigManager.instance.init();
    try {
      final data = map.map((k, v) => MapEntry(k, v.toJson()));
      await ServerConfigManager.instance.preferences?.setString(key, jsonEncode(data));
    } catch (_) {}
  }
}
