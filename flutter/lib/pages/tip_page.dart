import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../common/app_theme.dart';
import '../models/film_models.dart';
import '../api/film_api.dart';
import '../utils/format_util.dart';
import '../utils/server_config_manager.dart';
import '../utils/source_guard.dart';
import '../components/page_header.dart';
import '../components/loading_view.dart';
import '../components/empty_state.dart';

/// 赞赏支持页面
class TipPage extends StatefulWidget {
  const TipPage({super.key});

  @override
  State<TipPage> createState() => _TipPageState();
}

class _TipPageState extends State<TipPage> {
  BasicConfig _config = BasicConfig();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SourceGuard.onReconnect(_onReconnect);
    _loadConfig();
  }

  @override
  void dispose() {
    SourceGuard.offReconnect(_onReconnect);
    super.dispose();
  }

  void _onReconnect() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
    });
    try {
      final config = await FilmApi.getSiteConfig(force: false);
      if (mounted) {
        setState(() {
          _config = config;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<TipChannel> _visibleChannels() {
    return _config.tipChannels.where((c) => c.qrImage.isNotEmpty || c.link.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final channels = _visibleChannels();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(title: _config.tipTitle.isNotEmpty ? _config.tipTitle : '赞赏支持'),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
              child: Center(
                child: Text(
                  _config.tipMessage.isNotEmpty ? _config.tipMessage : '如果这个站对你有帮助，欢迎请作者喝杯咖啡',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingView(label: '加载中')
                  : channels.isEmpty
                      ? const EmptyState(
                          title: '暂未配置赞赏渠道',
                          icon: Icons.card_giftcard_rounded,
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppTheme.spaceLg),
                              itemCount: channels.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 24),
                              itemBuilder: (context, index) {
                                final item = channels[index];
                                final qrUrl = ServerConfigManager.instance.resolveMediaUrl(item.qrImage);

                                return Column(
                                  children: [
                                    Text(
                                      item.label,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (qrUrl.isNotEmpty)
                                      Container(
                                        width: 200,
                                        height: 200,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: CachedNetworkImage(
                                            imageUrl: qrUrl,
                                            httpHeaders: FormatUtil.imageHeaders(qrUrl),
                                            fit: BoxFit.contain,
                                            placeholder: (context, url) => const Center(
                                              child: CircularProgressIndicator(color: AppTheme.accent),
                                            ),
                                            errorWidget: (context, url, error) => const Center(
                                              child: Text('图片加载失败', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
