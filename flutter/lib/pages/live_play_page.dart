import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/film_api.dart';
import '../api/http_client.dart';
import '../common/app_theme.dart';
import '../components/loading_view.dart';
import '../components/player/live_play_body.dart';
import '../components/player/live_play_error_view.dart';
import '../components/player/video_player_widget.dart';
import '../models/film_models.dart';
import '../services/pip_manager.dart';
import '../utils/app_orientation.dart';
import '../utils/app_settings_manager.dart';
import '../utils/breakpoint.dart';
import '../utils/favorite_manager.dart';
import '../utils/history_manager.dart';
import '../utils/play_navigation.dart';
import '../utils/play_resume.dart';
import '../utils/server_config_manager.dart';
import '../utils/source_guard.dart';
import '../utils/split_cutout_insets.dart';

/// 采集源现场播放页，布局对齐自定义播放页（播放器 + 详情/选集 + 同类推荐）
class LivePlayPage extends StatefulWidget {
  final String sourceId;
  final String sourceMid;
  final int? episodeIndex;
  final double? currentTime;
  final String title;

  const LivePlayPage({
    super.key,
    required this.sourceId,
    required this.sourceMid,
    this.episodeIndex,
    this.currentTime,
    this.title = '',
  });

  @override
  State<LivePlayPage> createState() => _LivePlayPageState();
}

class _LivePlayPageState extends State<LivePlayPage> with WidgetsBindingObserver {
  late String _sourceMid;
  bool _loading = true;
  String _errorText = '';
  String _name = '';
  String _picture = '';
  String _subTitle = '';
  String _actor = '';
  String _plot = '';
  MovieDescriptor? _descriptor;
  List<PlaySource> _sources = [];
  String _playingSourceId = '';
  String _viewingSourceId = '';
  int _episodeIndex = 0;
  String _playUrl = '';
  int _playToken = 0;
  String _playTitle = '';
  double _initialTime = 0;
  List<MovieBasicInfo> _related = [];
  bool _relateLoading = false;
  int _activeTab = 0;
  bool _playerFull = false;
  final GlobalKey _videoKey = GlobalKey();
  String _sourceName = '';
  double _lastCurrentTime = 0;
  double _lastDuration = 0;
  bool _persistEnabled = true;
  bool _isPipActive = false;
  bool _isFav = false;
  bool _trackedEntry = false;

  String get _historyId => PlayNavigation.livePlayHistoryId(widget.sourceId, _sourceMid);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PipManager.instance.addListener(_onPipChanged);
    _isPipActive = PipManager.instance.isPipActive;
    _sourceMid = widget.sourceMid;
    _episodeIndex = widget.episodeIndex ?? 0;
    _initialTime = widget.currentTime ?? 0;
    _lastCurrentTime = _initialTime;
    if (widget.title.isNotEmpty) _name = widget.title;
    SourceGuard.onReconnect(_onReconnect);
    FavoriteManager.onFavoriteChange(_syncFavoriteState);
    _syncFavoriteState();
    _initPlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PipManager.instance.removeListener(_onPipChanged);
    FavoriteManager.offFavoriteChange(_syncFavoriteState);
    _persistHistory(_lastCurrentTime, _lastDuration);
    try {
      SystemChrome.setPreferredOrientations(kAutoRotationOrientations);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
    SourceGuard.offReconnect(_onReconnect);
    super.dispose();
  }

  Future<void> _syncFavoriteState() async {
    if (_historyId.isEmpty) return;
    final fav = await FavoriteManager.find(_historyId);
    if (!mounted) return;
    setState(() {
      _isFav = fav != null;
      if (_name.isEmpty && fav != null && fav.name.isNotEmpty) {
        _name = fav.name;
        _picture = fav.picture;
      }
    });
    if (_name.isEmpty) {
      final prev = await HistoryManager.find(_historyId);
      if (!mounted) return;
      if (_name.isEmpty && prev != null && prev.name.isNotEmpty) {
        setState(() {
          _name = prev.name;
          _picture = prev.picture;
        });
      }
    }
  }

  void _onPipChanged(bool active) {
    if (mounted && _isPipActive != active) {
      setState(() => _isPipActive = active);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _lastCurrentTime > 0) {
      _persistHistory(_lastCurrentTime, _lastDuration);
    }
  }

  void _onReconnect() {
    _persistEnabled = false;
    _loadPlay();
  }

  Future<void> _initPlay() async {
    int targetEpIndex = widget.episodeIndex ?? -1;
    double targetTime = widget.currentTime ?? -1;

    if (_historyId.isNotEmpty) {
      try {
        final prev = await HistoryManager.find(_historyId);
        if (prev != null) {
          if (_name.isEmpty && prev.name.isNotEmpty) {
            _name = prev.name;
          }
          if (targetEpIndex < 0 && prev.episodeIndex >= 0) {
            targetEpIndex = prev.episodeIndex;
          }
          if (targetTime < 0) {
            final ended = prev.duration > 0 && prev.currentTime >= prev.duration - 3;
            targetTime = ended ? 0 : prev.currentTime;
          }
          _lastDuration = prev.duration;
        }
      } catch (_) {}
    }

    _episodeIndex = targetEpIndex >= 0 ? targetEpIndex : 0;
    _initialTime = targetTime >= 0 ? targetTime : 0;
    _lastCurrentTime = _initialTime;
    await _loadPlay();
  }

  Future<void> _loadPlay() async {
    if (widget.sourceId.isEmpty || _sourceMid.isEmpty) {
      setState(() {
        _errorText = '缺少采集源播放参数';
        _loading = false;
      });
      return;
    }
    if (_sources.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final info = await FilmApi.getLivePlayInfo(
        widget.sourceId,
        _sourceMid,
        episode: _episodeIndex,
      );
      if (!mounted) return;
      final detail = info.detail;
      setState(() {
        _name = detail.name;
        _picture = detail.picture;
        _descriptor = detail.descriptor;
        _subTitle = detail.descriptor.subTitle;
        _actor = detail.descriptor.actor;
        _plot = detail.descriptor.content.isNotEmpty ? detail.descriptor.content : detail.descriptor.blurb;
        _sources = detail.list;
        _playingSourceId = info.currentPlayFrom.isNotEmpty
            ? info.currentPlayFrom
            : (detail.list.isNotEmpty ? detail.list.first.id : '');
        _viewingSourceId = _playingSourceId;
        _episodeIndex = info.currentEpisode;
        _playUrl = info.current.link;
        _playTitle = '${detail.name} · ${info.current.episode}';
        _sourceName = _findSource(_playingSourceId)?.name ?? (widget.sourceId.isNotEmpty ? widget.sourceId : '采集源');
        _errorText = '';
        _loading = false;
        _persistEnabled = true;
      });
      _persistHistory();
      if (!_trackedEntry) {
        _trackedEntry = true;
        HttpClient.instance.trackView('play', _historyId, 'LivePlayPage', '', '', '', widget.sourceId);
      }
      final cid = detail.rawCid > 0 ? detail.rawCid : detail.cid;
      _loadRelate(cid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_name.isEmpty) {
          _errorText = '$e';
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      });
    }
  }

  Future<void> _loadRelate(dynamic cid) async {
    if (widget.sourceId.isEmpty) return;
    setState(() => _relateLoading = true);
    try {
      final list = await FilmApi.getLiveRelate(
        widget.sourceId,
        cid: cid,
        sid: _sourceMid,
      );
      if (!mounted) return;
      setState(() {
        _related = list;
        _relateLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _related = [];
        _relateLoading = false;
      });
    }
  }

  PlaySource? _findSource(String id) {
    for (final source in _sources) {
      if (source.id == id) return source;
    }
    return _sources.isNotEmpty ? _sources.first : null;
  }

  void _selectEpisode(String sourceId, int index) {
    if (_playingSourceId == sourceId && _episodeIndex == index && _playUrl.isNotEmpty) return;
    final source = _findSource(sourceId);
    if (source == null || index < 0 || index >= source.linkList.length) return;
    final episode = source.linkList[index];
    setState(() {
      _playingSourceId = sourceId;
      _viewingSourceId = sourceId;
      _episodeIndex = index;
      _initialTime = 0;
      _lastCurrentTime = 0;
      _lastDuration = 0;
      _playUrl = episode.link;
      _playToken++;
      _playTitle = '$_name · ${episode.episode}';
      _sourceName = source.name;
    });
    _persistHistory(0, 0);
  }

  bool get _hasNext {
    final source = _findSource(_playingSourceId);
    return source != null && _episodeIndex < source.linkList.length - 1;
  }

  bool get _hasPrev => _episodeIndex > 0 && _findSource(_playingSourceId) != null;

  void _playPrev() {
    if (!_hasPrev) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已经是第一集了')));
      return;
    }
    _selectEpisode(_playingSourceId, _episodeIndex - 1);
  }

  void _playNext() {
    if (!_hasNext) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已经是最后一集了')));
      return;
    }
    _selectEpisode(_playingSourceId, _episodeIndex + 1);
  }

  Future<void> _openRelated(MovieBasicInfo film) async {
    String newSid = '';
    if (film.sourceMid > 0) {
      newSid = '${film.sourceMid}';
    } else if (film.mid.isNotEmpty) {
      newSid = film.mid;
    } else if (film.id > 0) {
      newSid = '${film.id}';
    }
    if (newSid.isEmpty || newSid == _sourceMid) return;

    _sourceMid = newSid;
    HttpClient.instance.trackView('play', _historyId, 'LivePlayPage', '', '', '', widget.sourceId);
    final resume = await PlayResume.fromHistory(_historyId);
    if (!mounted) return;
    setState(() {
      _name = '';
      _sources = [];
      _playUrl = '';
      _loading = true;
      _episodeIndex = resume.episodeIndex;
      _initialTime = resume.currentTime;
      _lastCurrentTime = resume.currentTime;
      _lastDuration = resume.duration;
      _activeTab = 0;
    });
    _loadPlay();
  }

  void _persistHistory([double? currentTime, double? duration]) {
    if (!_persistEnabled || _historyId.isEmpty || _name.isEmpty) return;
    if (ServerConfigManager.instance.storageScope().isEmpty) return;
    final source = _findSource(_playingSourceId);
    final fallback = MovieUrlInfo(episode: _playTitle, link: _playUrl);
    final episode = (source != null && source.linkList.length > _episodeIndex)
        ? source.linkList[_episodeIndex]
        : fallback;
    HistoryManager.find(_historyId).then((prev) {
      HistoryManager.save(HistoryItem(
        id: _historyId,
        name: _name,
        picture: _picture,
        sourceId: widget.sourceId,
        sourceName: source?.name ?? _sourceName,
        episodeIndex: _episodeIndex,
        episode: episode.episode,
        currentTime: currentTime ?? (prev?.currentTime ?? 0),
        duration: duration ?? (prev?.duration ?? 0),
        timeStamp: DateTime.now().millisecondsSinceEpoch,
      ));
    });
  }

  void _setFullscreen(bool full, {bool isPortrait = false}) {
    if (_playerFull == full) return;
    setState(() => _playerFull = full);
    try {
      if (full) {
        SystemChrome.setPreferredOrientations(isPortrait ? [DeviceOrientation.portraitUp] : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations(kAutoRotationOrientations);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {}
  }

  Widget _buildVideoPlayer({
    required bool isFull,
    bool edgeHud = false,
    double? overrideLeftInset,
  }) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final useInset = isFull || edgeHud;
    return VideoPlayerWidget(
      key: _videoKey,
      videoUrl: _playUrl,
      reloadToken: _playToken,
      title: _playTitle,
      poster: ServerConfigManager.instance.resolveMediaUrl(_picture),
      initialTime: _initialTime,
      showBack: true,
      isFull: isFull,
      edgeHud: edgeHud,
      topInset: useInset ? viewPadding.top : 0,
      bottomInset: useInset ? viewPadding.bottom : 0,
      leftInset: overrideLeftInset ?? (useInset ? viewPadding.left : 0),
      rightInset: isFull ? viewPadding.right : (edgeHud ? AppTheme.safeEdge : 0),
      hasPrev: _hasPrev,
      hasNext: _hasNext,
      onBack: () => _playerFull ? _setFullscreen(false) : Navigator.pop(context),
      onEnded: () { if (AppSettingsManager.instance.autoPlayNext && _hasNext) _playNext(); },
      onPrev: _playPrev,
      onNext: _playNext,
      onFullscreenChange: _setFullscreen,
      onProgress: (cur, dur) {
        _lastCurrentTime = cur;
        _lastDuration = dur;
        _persistHistory(cur, dur);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final split = !_playerFull && size.width >= Breakpoint.md && size.width > size.height;
    final isFullMode = _playerFull;

    return PopScope(
      canPop: !_isPipActive && !isFullMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isFullMode) {
          _setFullscreen(false);
        }
      },
      child: Scaffold(
        backgroundColor: (_isPipActive || isFullMode) ? Colors.black : AppTheme.bg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          top: !_isPipActive && !isFullMode && !split,
          bottom: !_isPipActive && !isFullMode && !split,
          left: !_isPipActive && !isFullMode && !split,
          right: !_isPipActive && !isFullMode && !split,
          child: _buildPlayBody(isFullMode: isFullMode, split: split),
        ),
      ),
    );
  }

  Widget _buildPlayBody({required bool isFullMode, required bool split}) {
    if (_loading && _sources.isEmpty) return const LoadingView(label: '正在打开播放页');
    if (_errorText.isNotEmpty && _sources.isEmpty) {
      return LivePlayErrorView(
        filmName: _name,
        errorText: _errorText,
        isFavorite: _isFav,
        onBack: () => Navigator.pop(context),
        onRetry: _loadPlay,
        onRemoveFavorite: () async {
          await FavoriteManager.remove(_historyId);
          if (!mounted) return;
          setState(() => _isFav = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已移出收藏')));
        },
      );
    }

    if (_isPipActive) {
      return SizedBox.expand(
        child: _buildVideoPlayer(isFull: false),
      );
    }

    if (isFullMode) {
      return SizedBox.expand(
        child: _buildVideoPlayer(isFull: true),
      );
    }

    return LivePlayBody(
      isSplit: split,
      playerWidget: _buildVideoPlayer(
        isFull: false,
        edgeHud: split,
        overrideLeftInset: split ? SplitCutoutInsets.resolve(MediaQuery.viewPaddingOf(context), padding: MediaQuery.paddingOf(context), displayFeatures: MediaQuery.displayFeaturesOf(context), size: MediaQuery.sizeOf(context)).left : null,
      ),
      activeTab: _activeTab,
      onTabChange: (tab) => setState(() => _activeTab = tab),
      filmId: _historyId,
      picture: _picture,
      name: _name,
      subTitle: _subTitle,
      actor: _actor,
      plot: _plot,
      descriptor: _descriptor,
      sources: _sources,
      playingSourceId: _playingSourceId,
      viewingSourceId: _viewingSourceId,
      episodeIndex: _episodeIndex,
      onViewSource: (id) => setState(() => _viewingSourceId = id),
      onSelectEpisode: (sourceId, index) => _selectEpisode(sourceId, index),
      relateLoading: _relateLoading,
      related: _related,
      onOpenRelated: _openRelated,
      sourceName: _sourceName,
    );
  }
}
