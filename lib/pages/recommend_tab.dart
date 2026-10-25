import 'dart:ui';
import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import '../models/film_models.dart';
import '../utils/breakpoint.dart';
import '../utils/source_guard.dart';
import '../api/film_api.dart';
import '../components/loading_view.dart';
import '../components/empty_state.dart';
import '../components/film_row.dart';
import '../utils/tv_focus_bridge.dart';
import '../components/tv_focus_item.dart';
import '../components/home_banner.dart';
import '../components/focus_wrap.dart';
import '../utils/favorite_manager.dart';

/// 首页推荐 Tab，对齐 OHOS `RecommendTab.ets`
class RecommendTab extends StatefulWidget {
  final String siteName;
  final VoidCallback? onOpenSearch;

  const RecommendTab({
    super.key,
    required this.siteName,
    this.onOpenSearch,
  });

  @override
  State<RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<RecommendTab> {
  static const _verticalPhysics = AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());
  static const _iconSize = 17.0, _tagHeight = 32.0, _glyphSize = 10.0, _labelSize = 13.0;
  static const _iconBg = Color(0x1FFA8C16), _iconBorder = Color(0x47FA8C16);
  static const _chipBg = Color(0x0DFFFFFF), _chipBorder = Color(0x1AFFFFFF);

  List<BannerItem> _banners = [];
  List<HomeSection> _sections = [];
  bool _loading = true;
  bool _fetchLock = false;
  String _errorText = '';
  double _headerAlpha = 0;
  int _reloadToken = 0;
  final ScrollController _scrollController = ScrollController();

  /// 焦点协调器：控制「分类标题行 ↔ 电影行」之间的方向键跳转。
  ///
  /// 这两片区域在几何上紧挨着，Flutter 默认的几何感知焦点遍历会让 ↓/↑
  /// 在其间反复横跳（电视上表现为焦点框乱窜）。这里显式指定跳转目标。
  final TvFocusBridge _focusBridge = TvFocusBridge();

  /// 区域名常量。
  static const String _zoneCategory = 'category';
  static const String _zoneRow = 'row';

  @override
  void initState() {
    super.initState();
    FavoriteManager.preload();
    _scrollController.addListener(_onScroll);
    SourceGuard.onReconnect(_onReconnect);
    _loadHome(fromPull: false);
  }

  @override
  void dispose() {
    _focusBridge.clear();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    SourceGuard.offReconnect(_onReconnect);
    super.dispose();
  }

  void _onReconnect() {
    FavoriteManager.preload();
    _loadHome(fromPull: false);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final y = _scrollController.offset;
    final alpha = y <= 0 ? 0.0 : (y / 160.0).clamp(0.0, 1.0);
    // 金标：差值 > 0.01，或到顶/到底必须写入，否则 0.01 阈值会把毛玻璃卡死
    if ((alpha - _headerAlpha).abs() > 0.01 || alpha == 0.0 || alpha == 1.0) {
      if (alpha == _headerAlpha) return;
      setState(() {
        _headerAlpha = alpha;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 1400)),
    );
  }

  Future<void> _loadHome({required bool fromPull, bool showHint = false}) async {
    if (_fetchLock) return;
    _fetchLock = true;
    if (!fromPull) {
      setState(() {
        _banners = [];
        _sections = [];
        _loading = true;
        _errorText = '';
      });
    }
    var ok = false;
    try {
      final home = await FilmApi.getHome();
      if (!mounted) return;
      setState(() {
        _banners = home.banners;
        _sections = home.content;
        _loading = false;
        _errorText = '';
        _reloadToken = DateTime.now().millisecondsSinceEpoch;
      });
      ok = true;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = '$e';
      });
    } finally {
      _fetchLock = false;
    }
    if (showHint && ok) {
      _toast('已更新');
    } else if (showHint && !ok && _errorText.isNotEmpty) {
      _toast(_errorText);
    }
  }

  List<HomeSection> _visibleSections() {
    return _sections.where((s) {
      if (!s.nav.show) return false;
      final films = s.movies.isNotEmpty ? s.movies : s.hot;
      return films.isNotEmpty;
    }).toList();
  }

  String _categoryGlyph(String name) {
    final text = name.trim();
    if (text.isEmpty) return '';
    return String.fromCharCodes(text.runes.take(1));
  }

  double _effectiveHeaderAlpha(bool wide) {
    if (_banners.isEmpty) return 1.0;
    if (wide) return (0.76 + 0.16 * _headerAlpha).clamp(0.0, 0.92);
    return _headerAlpha;
  }

  void _openSearch() {
    if (widget.onOpenSearch != null) {
      widget.onOpenSearch!();
    } else {
      Navigator.pushNamed(context, '/search');
    }
  }

  void _openFilter(int pid) {
    Navigator.pushNamed(context, '/filter', arguments: {'Pid': '$pid'});
  }

  Widget _categoryEntry(HomeSection section, bool wide, int index) {
    final glyph = _categoryGlyph(section.nav.name);
    return Padding(
      padding: EdgeInsets.only(right: wide ? 8 : AppTheme.spaceSm),
      // TvFocusItem：按 ↓ 跳到**对应的**电影行第一张卡，
      // 按 ↑ 跳回分类标题行 —— 不再靠几何匹配猜。
      child: TvFocusItem(
        bridge: _focusBridge,
        zone: _zoneCategory,
        index: index,
        downZone: _zoneRow,
        downIndex: index,
        upZone: _zoneCategory,
        focusRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openFilter(section.nav.id),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: Container(
              height: wide ? 35 : _tagHeight,
              padding: EdgeInsets.only(
                left: wide ? 8 : (AppTheme.spaceSm - 2),
                right: wide ? 13 : (AppTheme.spaceMd - 1),
              ),
              decoration: BoxDecoration(
                color: wide ? const Color(0x0FFFFFFF) : _chipBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                  width: wide ? 0.8 : 0.8,
                  color: wide ? const Color(0x1FFFFFFF) : _chipBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (glyph.isNotEmpty) ...[
                    Container(
                      width: wide ? 19 : _iconSize,
                      height: wide ? 19 : _iconSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: wide ? const Color(0x24FA8C16) : _iconBg,
                        borderRadius: BorderRadius.circular(wide ? 9.5 : _iconSize / 2),
                        border: Border.all(
                          width: wide ? 0.7 : 0.6,
                          color: wide ? const Color(0x52FA8C16) : _iconBorder,
                        ),
                      ),
                      child: Text(
                        glyph,
                        style: TextStyle(
                          fontFamily: AppTheme.calligraphyFont,
                          fontSize: wide ? 11 : _glyphSize,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: wide ? 6 : (AppTheme.spaceSm - 2)),
                  ],
                  Text(
                    section.nav.name,
                    style: TextStyle(
                      fontSize: wide ? 13.5 : _labelSize,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stateActions({required String label, required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pillButton(icon: Icons.link_rounded, label: '更换软件源', accent: true, onTap: () => Navigator.pushNamed(context, '/server_config')),
        const SizedBox(height: 12),
        _pillButton(icon: Icons.refresh_rounded, label: label, accent: false, onTap: onTap),
      ],
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required bool accent,
    required VoidCallback onTap,
  }) {
    return FocusHighlight(
      radius: BorderRadius.circular(AppTheme.radiusPill),
      child: Material(
        color: accent ? AppTheme.accent : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: Container(
            width: 148,
            height: 38,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: AppTheme.textPrimary),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 指示器从顶栏底边往下出现，对齐 OHOS `topInset + 48 + pullDistance - 38`。
  Widget _wrapRefresh({required double topInset, required Widget child}) {
    return RefreshIndicator(
      onRefresh: () => _loadHome(fromPull: true, showHint: true),
      color: AppTheme.accent,
      backgroundColor: AppTheme.bgCard,
      edgeOffset: topInset + 48,
      displacement: 16,
      child: child,
    );
  }

  Widget _scrollableState({
    required double topInset,
    required double leftInset,
    required double rightInset,
    required Widget child,
  }) {
    return _wrapRefresh(
      topInset: topInset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: _verticalPhysics,
            padding: EdgeInsets.only(left: leftInset, right: rightInset),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.only(top: 48 + topInset),
                  child: Center(child: child),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(double topInset, double leftInset, double rightInset, bool wide) {
    final alpha = _effectiveHeaderAlpha(wide);
    final searchBg = Color.fromRGBO(
      (22 * alpha).round(),
      (23 * alpha).round(),
      (31 * alpha).round(),
      0.36 + 0.64 * alpha,
    );
    final searchBorder = Color.fromRGBO(255, 255, 255, 0.16 * (1 - alpha) + 0.08 * alpha);
    final bar = Container(
      height: 48 + topInset,
      padding: EdgeInsets.only(
        top: topInset,
        left: AppTheme.spaceLg + leftInset,
        right: AppTheme.spaceLg + rightInset,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bg.withValues(alpha: alpha),
        border: Border(
          bottom: BorderSide(
            width: (wide || _headerAlpha > 0.5) ? 0.5 : 0,
            color: Color.fromRGBO(255, 255, 255, wide ? 0.08 : ((_headerAlpha - 0.5) * 0.16).clamp(0.0, 1.0)),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.subscriptions_rounded, size: 20, color: AppTheme.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.siteName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                shadows: [Shadow(blurRadius: 8, color: Color(0xD9000000), offset: Offset(0, 1))],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FocusTap(
            focusRadius: BorderRadius.circular(AppTheme.radiusPill),
            onTap: _openSearch,
            child: Container(
              height: 34,
              padding: const EdgeInsets.only(left: 12, right: 14),
              decoration: BoxDecoration(
                color: searchBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: searchBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_rounded, size: 14, color: Color(0xBFFFFFFF)),
                  SizedBox(width: 6),
                  Text('搜索', style: TextStyle(fontSize: 12, color: Color(0x8CFFFFFF))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (!wide && _headerAlpha <= 0) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: bar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final leftInset = media.padding.left;
    final rightInset = media.padding.right;
    final wide = Breakpoint.isWideWidth(media.size.width);
    final sections = _visibleSections();

    Widget body;
    if (_loading) {
      body = Padding(
        padding: EdgeInsets.only(top: 48 + topInset, left: leftInset, right: rightInset),
        child: const LoadingView(label: '正在加载推荐'),
      );
    } else if (_errorText.isNotEmpty) {
      body = Padding(
        padding: EdgeInsets.only(top: 48 + topInset, left: leftInset, right: rightInset),
        child: Center(
          child: SingleChildScrollView(
            child: EmptyState(
              title: '加载失败',
              subtitle: _errorText,
              icon: Icons.error_outline_rounded,
              action: _stateActions(label: '刷新', onTap: () => _loadHome(fromPull: false, showHint: true)),
            ),
          ),
        ),
      );
    } else if (_banners.isEmpty && sections.isEmpty) {
      body = _scrollableState(
        topInset: topInset,
        leftInset: leftInset,
        rightInset: rightInset,
        child: EmptyState(
          title: '暂无影片数据',
          subtitle: '当前软件源内暂无影片或尚未采集，可下拉刷新或更换软件源',
          icon: Icons.movie_outlined,
          action: _stateActions(label: '刷新', onTap: () => _loadHome(fromPull: true, showHint: true)),
        ),
      );
    } else {
      final topSpace = wide
          ? (48 + topInset + 8)
          : (_banners.isEmpty ? (48 + topInset + 12) : 0.0);
      body = _wrapRefresh(
        topInset: topInset,
        // 用 CustomScrollView + SliverList 让各 section **懒构建**。
        // 原先的 SingleChildScrollView + Column 会一次性构建全部 8 个 section
        // （每行 14 张卡 → 200+ 张 FilmCard 同时挂载），是首屏卡顿的重要原因。
        child: CustomScrollView(
          controller: _scrollController,
          physics: _verticalPhysics,
          slivers: [
            if (topSpace > 0)
              SliverToBoxAdapter(child: SizedBox(height: topSpace)),
            SliverToBoxAdapter(
              child: HomeBanner(key: ValueKey(_reloadToken), banners: _banners),
            ),
            if (sections.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: wide ? 14 : AppTheme.spaceLg),
                  // FocusTraversalGroup：把「分类标题行」划为一个独立的遍历组。
                  //
                  // 为什么要分组：分类行是**横向**排列，下面的 FilmRow 也是横向排列，
                  // 两者几何位置挨得很近。默认的焦点遍历按几何位置找最近候选，
                  // 于是 ↓ 键会在「分类标题」和「电影卡片」之间反复横跳 ——
                  // 表现为焦点框在两处之间乱窜。
                  //
                  // 分组后，↓ 键按**组的顺序**移动（分类行组 → 第 1 个 FilmRow 组
                  // → 第 2 个 …），行为完全确定。
                  child: FocusTraversalGroup(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.only(
                        left: AppTheme.spaceLg + leftInset,
                        right: AppTheme.spaceLg + rightInset,
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < sections.length; i++)
                            _categoryEntry(sections[i], wide, i),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SliverList.builder(
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                final movies = section.movies.isNotEmpty ? section.movies : section.hot;
                return FilmRow(
                  title: section.nav.name,
                  films: movies,
                  pid: section.nav.id,
                  leftInset: leftInset,
                  rightInset: rightInset,
                  onMore: () => _openFilter(section.nav.id),
                  // 焦点协调：卡片按 ↑ 跳回对应的分类标题项；
                  // 分类项按 ↓ 跳到本行第一张卡。
                  focusBridge: _focusBridge,
                  focusZone: _zoneRow,
                  focusIndex: index,
                  focusUpZone: _zoneCategory,
                  focusUpIndex: index,
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceSm)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        body,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _header(topInset, leftInset, rightInset, wide),
        ),
      ],
    );
  }
}
