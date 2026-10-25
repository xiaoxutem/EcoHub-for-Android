import 'dart:convert';
import 'server_config_manager.dart';

const String _keySearchHistory = 'search_history';
const int _maxSearchHistory = 20;

/// 搜索历史记录管理器（按源隔离）
class SearchHistoryManager {
  static String _dataKey() {
    return ServerConfigManager.instance.scopedKey(_keySearchHistory);
  }

  static Future<List<String>> list() async {
    final key = _dataKey();
    if (key.isEmpty) return [];
    final pref = ServerConfigManager.instance.preferences;
    if (pref == null) await ServerConfigManager.instance.init();
    try {
      final raw = ServerConfigManager.instance.preferences?.getString(key) ?? '[]';
      final list = jsonDecode(raw);
      if (list is List) {
        return list.map((e) => '$e').toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;
    final current = await list();
    final filtered = current.where((item) => item != kw).toList();
    filtered.insert(0, kw);
    if (filtered.length > _maxSearchHistory) {
      filtered.removeRange(_maxSearchHistory, filtered.length);
    }
    await _saveList(filtered);
  }

  static Future<void> remove(String keyword) async {
    final current = await list();
    final filtered = current.where((item) => item != keyword).toList();
    await _saveList(filtered);
  }

  static Future<void> clear() async {
    await _saveList([]);
  }

  static Future<void> _saveList(List<String> list) async {
    final key = _dataKey();
    if (key.isEmpty) return;
    final pref = ServerConfigManager.instance.preferences;
    if (pref == null) await ServerConfigManager.instance.init();
    try {
      await ServerConfigManager.instance.preferences?.setString(key, jsonEncode(list));
    } catch (_) {}
  }
}
