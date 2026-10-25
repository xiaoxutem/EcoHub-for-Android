import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import 'focus_wrap.dart';

class SearchSuggestPane extends StatelessWidget {
  final List<String> searchHistory;
  final List<String> hotKeywords;
  final ValueChanged<String> onSelectKeyword;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onRemoveHistory;

  const SearchSuggestPane({
    super.key,
    required this.searchHistory,
    required this.hotKeywords,
    required this.onSelectKeyword,
    required this.onClearHistory,
    required this.onRemoveHistory,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - AppTheme.spaceLg * 2;
        final maxHotTextWidth = (availableWidth - 52).clamp(60.0, 720.0);
        final maxHistoryTextWidth = (availableWidth - 64).clamp(60.0, 720.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (searchHistory.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '搜索历史',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    FocusTap(
                      focusRadius: BorderRadius.circular(AppTheme.radiusSm),
                      onTap: onClearHistory,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.textMuted),
                          SizedBox(width: 2),
                          Text('清空', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: searchHistory.map((item) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FocusHighlight(
                            radius: const BorderRadius.horizontal(
                              left: Radius.circular(AppTheme.radiusPill),
                            ),
                            child: InkWell(
                              onTap: () => onSelectKeyword(item),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppTheme.radiusPill)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxHistoryTextWidth),
                                  child: Text(
                                    item,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          FocusTap(
                            focusRadius: const BorderRadius.all(Radius.circular(16)),
                            onTap: () => onRemoveHistory(item),
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8, left: 2),
                              child: Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              if (hotKeywords.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 16, color: AppTheme.accent),
                    SizedBox(width: 4),
                    Text(
                      '热门搜索',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(hotKeywords.length, (index) {
                    final item = hotKeywords[index];
                    final isTop3 = index < 3;
                    return FocusHighlight(
                      radius: BorderRadius.circular(AppTheme.radiusPill),
                      child: InkWell(
                        onTap: () => onSelectKeyword(item),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isTop3 ? AppTheme.bgChip : AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            border: Border.all(
                              color: isTop3 ? AppTheme.accentSoft : AppTheme.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isTop3 ? AppTheme.accent : AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxHotTextWidth),
                                child: Text(
                                  item,
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
