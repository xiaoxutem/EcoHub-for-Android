import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV 焦点区域协调器。
///
/// ## 为什么需要它
///
/// 推荐页 / 更新页的结构是「横向分类标题行 + 若干横向电影行」。
/// 这些行在几何上挨得很近，而 Flutter 默认的焦点遍历
/// （[ReadingOrderTraversalPolicy]）是**几何感知**的：
/// 按方向键时会在候选里挑「几何上最近」的元素。
///
/// 结果就是 ↓ 键在「分类标题」和「电影卡片」之间反复横跳 ——
/// 电视上表现为焦点框在两处之间乱窜，完全无法预测。
///
/// 单靠 [FocusTraversalGroup] 解决不了：它只是限定遍历范围，
/// 范围内的方向键选择依然是几何匹配。
///
/// ## 做法
///
/// 把「区域」显式登记进来，方向键跨区域时**直接指定目标**：
///
/// ```dart
/// final bridge = TvFocusBridge();
/// // 分类项按 ↓ → 跳到对应的电影行第一张卡
/// bridge.register(zone: 'category', index: 0, node: categoryNode,
///     downTo: 'row', downIndex: 0);
/// // 电影卡按 ↑ → 跳回对应的分类项
/// bridge.register(zone: 'row', index: 0, node: cardNode, upTo: 'category');
/// ```
///
/// 区域内移动（→/←）仍交给 Flutter 默认行为，
/// 只有**跨区域**（↓/↑）才由本协调器接管 —— 结果完全确定。
/// 一个可聚焦节点及其跨区域跳转目标。
class TvFocusBridgeEntry {
  final FocusNode node;

  /// 按 ↓ 时跳转到的区域。
  final String? downZone;

  /// 按 ↓ 时跳转到的区域内的下标。
  final int downIndex;

  /// 按 ↑ 时跳转到的区域。
  final String? upZone;

  /// 按 ↑ 时跳转到的区域内的下标。
  final int upIndex;

  /// 按 → 时跳转到的区域。
  final String? rightZone;

  /// 按 → 时跳转到的区域内的下标。
  final int rightIndex;

  /// 按 ← 时跳转到的区域。
  final String? leftZone;

  /// 按 ← 时跳转到的区域内的下标。
  final int leftIndex;

  const TvFocusBridgeEntry({
    required this.node,
    this.downZone,
    this.downIndex = 0,
    this.upZone,
    this.upIndex = 0,
    this.rightZone,
    this.rightIndex = 0,
    this.leftZone,
    this.leftIndex = 0,
  });
}

class TvFocusBridge {

  /// 区域名 → 该区域内登记的节点列表。
  final Map<String, List<TvFocusBridgeEntry>> _zones = {};

  /// 登记一个可聚焦节点。
  void register({
    required String zone,
    required int index,
    required FocusNode node,
    String? downZone,
    int downIndex = 0,
    String? upZone,
    int upIndex = 0,
    String? rightZone,
    int rightIndex = 0,
    String? leftZone,
    int leftIndex = 0,
  }) {
    final list = _zones.putIfAbsent(zone, () => <TvFocusBridgeEntry>[]);
    final entry = TvFocusBridgeEntry(
      node: node,
      downZone: downZone,
      downIndex: downIndex,
      upZone: upZone,
      upIndex: upIndex,
      rightZone: rightZone,
      rightIndex: rightIndex,
      leftZone: leftZone,
      leftIndex: leftIndex,
    );
    // 列表按下标存放，便于按下标取回。
    while (list.length <= index) {
      list.add(TvFocusBridgeEntry(node: FocusNode(debugLabel: 'placeholder')));
    }
    list[index] = entry;
  }

  /// 解除登记（组件销毁时调用）。
  void unregister(String zone, int index) {
    final list = _zones[zone];
    if (list == null || index >= list.length) return;
    list[index] = TvFocusBridgeEntry(node: FocusNode(debugLabel: 'placeholder'));
  }

  /// 查找某个区域某个下标的节点。
  FocusNode? nodeOf(String zone, int index) {
    final list = _zones[zone];
    if (list == null || index < 0 || index >= list.length) return null;
    return list[index].node;
  }

  /// 处理方向键：若该按键有跨区域目标，则请求焦点并返回 true。
  ///
  /// [zone] / [index] 标识当前焦点所在的位置。
  bool handleDirection({
    required String zone,
    required int index,
    required LogicalKeyboardKey key,
  }) {
    final list = _zones[zone];
    if (list == null || index < 0 || index >= list.length) return false;
    final entry = list[index];

    String? targetZone;
    int targetIndex = 0;
    if (key == LogicalKeyboardKey.arrowDown) {
      targetZone = entry.downZone;
      targetIndex = entry.downIndex;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      targetZone = entry.upZone;
      targetIndex = entry.upIndex;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      targetZone = entry.rightZone;
      targetIndex = entry.rightIndex;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      targetZone = entry.leftZone;
      targetIndex = entry.leftIndex;
    }
    if (targetZone == null) return false;

    final target = nodeOf(targetZone, targetIndex);
    if (target == null) return false;
    if (!target.canRequestFocus) return false;
    // 先把目标滚进视口再给焦点 —— 否则焦点会落到屏幕外的元素上，
    // 用户看到的就是「焦点框突然不见了」。
    final ctx = target.context;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0,
        duration: const Duration(milliseconds: 200),
      );
    }
    target.requestFocus();
    return true;
  }

  /// 清空所有登记。
  void clear() {
    _zones.clear();
  }
}
