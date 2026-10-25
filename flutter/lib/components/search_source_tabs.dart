import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import '../models/film_models.dart';

class SearchSourceTabs extends StatefulWidget {
  final List<SearchSourceTab> sources;
  final String activeId;
  final ValueChanged<String> onChange;

  const SearchSourceTabs({
    super.key,
    required this.sources,
    required this.activeId,
    required this.onChange,
  });

  @override
  State<SearchSourceTabs> createState() => _SearchSourceTabsState();
}

class _SearchSourceTabsState extends State<SearchSourceTabs> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _chipKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollToActive(false);
  }

  @override
  void didUpdateWidget(SearchSourceTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeId != widget.activeId ||
        oldWidget.sources.length != widget.sources.length) {
      _scrollToActive(true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(bool smooth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _chipKeys[widget.activeId];
      final ctx = key?.currentContext;
      if (ctx == null) return;
      final renderObject = ctx.findRenderObject();
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable == null || renderObject == null) return;

      scrollable.position.ensureVisible(
        renderObject,
        alignment: 0.5,
        duration: smooth ? const Duration(milliseconds: 260) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sources.length <= 1) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
        itemBuilder: (context, index) {
          final tab = widget.sources[index];
          final active = tab.id == widget.activeId;
          final metaColor = active ? Colors.white : AppTheme.textSecondary;
          final itemKey = _chipKeys.putIfAbsent(tab.id, () => GlobalKey());

          return ChoiceChip(
            key: itemKey,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab.name),
                const SizedBox(width: 4),
                if (tab.loading)
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: metaColor,
                    ),
                  )
                else
                  Text('${tab.count}'),
              ],
            ),
            selected: active,
            onSelected: (_) => widget.onChange(tab.id),
            selectedColor: AppTheme.accent,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: metaColor,
            ),
            backgroundColor: AppTheme.bgCard,
            shape: const StadiumBorder(),
            side: BorderSide.none,
            showCheckmark: false,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: widget.sources.length,
      ),
    );
  }
}
