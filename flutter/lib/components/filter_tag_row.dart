import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import 'focus_wrap.dart';

/// 筛选标签行，对齐 OHOS `FilterTagRow.ets`；横向滚动对齐 EcoTV FilterBar。
class FilterTagRow extends StatefulWidget {
  final String filterKey;
  final String title;
  final List<String> names;
  final List<String> values;
  final String selected;
  final void Function(String key, String value) onPick;

  const FilterTagRow({
    super.key,
    required this.filterKey,
    required this.title,
    required this.names,
    required this.values,
    required this.selected,
    required this.onPick,
  });

  @override
  State<FilterTagRow> createState() => _FilterTagRowState();
}

class _FilterTagRowState extends State<FilterTagRow> {
  final ScrollController _scroller = ScrollController();
  List<GlobalKey> _chipKeys = const [];

  @override
  void initState() {
    super.initState();
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpSelected(false));
  }

  @override
  void didUpdateWidget(covariant FilterTagRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.names.length != widget.names.length) {
      _syncKeys();
    }
    if (oldWidget.selected != widget.selected || oldWidget.values != widget.values) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpSelected(true));
    }
  }

  @override
  void dispose() {
    _scroller.dispose();
    super.dispose();
  }

  void _syncKeys() {
    _chipKeys = List.generate(widget.names.length, (i) => GlobalKey());
  }

  bool _isSelected(String val) {
    if (widget.filterKey == 'Sort' && (widget.selected.isEmpty || widget.selected == 'update_stamp')) {
      return val == 'update_stamp';
    }
    return widget.selected == val;
  }

  void _jumpSelected(bool smooth) {
    final idx = widget.values.indexOf(widget.selected);
    if (idx < 0 || idx >= _chipKeys.length) return;
    final ctx = _chipKeys[idx].currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    // 只滚动当前行的横向 scroller：Scrollable.ensureVisible 会向上遍历所有可滚动祖先，
    // 误触发外层 CustomScrollView 纵向滚动（导致筛选头只露出一半）。
    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null || renderObject == null) return;
    scrollable.position.ensureVisible(
      renderObject,
      alignment: 0,
      duration: smooth ? const Duration(milliseconds: 220) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.names.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.only(left: AppTheme.spaceLg),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                widget.title,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: AppTheme.spaceLg),
                child: Row(
                  children: [
                    for (var i = 0; i < widget.names.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _chip(i),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(int index) {
    final name = widget.names[index];
    final val = index < widget.values.length ? widget.values[index] : name;
    final active = _isSelected(val);
    return FocusTap(
      key: _chipKeys[index],
      focusRadius: BorderRadius.circular(AppTheme.radiusPill),
      onTap: () => widget.onPick(widget.filterKey, val),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 13,
            color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
