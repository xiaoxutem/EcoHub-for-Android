import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import 'filter_tag_row.dart';

/// 筛选栏本体，参考 EcoTV `views/filter/filter_bar.dart`。
/// `Column(mainAxisSize: min)` 被子行撑开，高度不写死。
class FilterBar extends StatelessWidget {
  final List<String> keys;
  final String Function(String key) titleOf;
  final List<String> Function(String key) namesOf;
  final List<String> Function(String key) valuesOf;
  final String Function(String key) selectedOf;
  final void Function(String key, String value) onPick;

  const FilterBar({
    super.key,
    required this.keys,
    required this.titleOf,
    required this.namesOf,
    required this.valuesOf,
    required this.selectedOf,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (keys.isEmpty) return const SizedBox.shrink();
    return ColoredBox(
      color: AppTheme.bgElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final key in keys)
              FilterTagRow(
                filterKey: key,
                title: titleOf(key),
                names: namesOf(key),
                values: valuesOf(key),
                selected: selectedOf(key),
                onPick: onPick,
              ),
          ],
        ),
      ),
    );
  }
}
