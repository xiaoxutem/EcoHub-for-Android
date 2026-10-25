import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import '../common/app_theme.dart';

const double _markdownImageMaxHeight = 160;

final md.ExtensionSet _safeMarkdownExtensions = md.ExtensionSet(
  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  List<md.InlineSyntax>.unmodifiable(<md.InlineSyntax>[
    md.StrikethroughSyntax(),
    md.AutolinkSyntax(),
    md.AutolinkExtensionSyntax(),
  ]),
);

bool isSafeMarkdownLink(String? href) {
  if (href == null || href.trim().isEmpty) return false;
  final uri = Uri.tryParse(href.trim());
  if (uri == null || uri.scheme.isEmpty) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'https' || scheme == 'http' || scheme == 'mailto';
}

bool isSafeMarkdownImageUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return uri.scheme.toLowerCase() == 'https';
}

/// 统一 Markdown 富文本渲染组件
class AppMarkdownView extends StatelessWidget {
  final String data;
  final double fontSize;
  final Color? textColor;

  const AppMarkdownView({
    super.key,
    required this.data,
    this.fontSize = 14.0,
    this.textColor,
  });

  Future<void> _handleLinkTap(String? href) async {
    final trimmed = href?.trim();
    if (!isSafeMarkdownLink(trimmed)) return;
    try {
      final uri = Uri.parse(trimmed!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? AppTheme.textSecondary;

    return MarkdownBody(
      data: data,
      selectable: false,
      shrinkWrap: true,
      fitContent: false,
      extensionSet: _safeMarkdownExtensions,
      onTapLink: (text, href, title) => _handleLinkTap(href),
      imageBuilder: (uri, title, alt) => _AppMarkdownImage(uri: uri, alt: alt),
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: fontSize,
          color: effectiveTextColor,
          height: 1.55,
        ),
        strong: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        em: TextStyle(fontStyle: FontStyle.italic, color: effectiveTextColor),
        h1: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
          height: 1.4,
        ),
        h2: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
          height: 1.4,
        ),
        h3: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
          height: 1.4,
        ),
        h4: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
          height: 1.4,
        ),
        listBullet: TextStyle(fontSize: fontSize, color: AppTheme.accent),
        listBulletPadding: const EdgeInsets.only(right: 6),
        a: const TextStyle(
          color: AppTheme.accent,
          decoration: TextDecoration.underline,
        ),
        code: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: AppTheme.accent,
          backgroundColor: AppTheme.bgChip,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.bgChip,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.border),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(fontSize: fontSize, color: AppTheme.textMuted),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.accent, width: 3)),
        ),
        pPadding: const EdgeInsets.only(bottom: 8),
        h1Padding: const EdgeInsets.only(top: 10, bottom: 6),
        h2Padding: const EdgeInsets.only(top: 8, bottom: 4),
        h3Padding: const EdgeInsets.only(top: 6, bottom: 4),
        h4Padding: const EdgeInsets.only(top: 4, bottom: 4),
      ),
    );
  }
}

class _AppMarkdownImage extends StatelessWidget {
  final Uri uri;
  final String? alt;

  const _AppMarkdownImage({required this.uri, this.alt});

  static String _resolveUrl(String raw) {
    if (raw.contains('img.shields.io')) {
      try {
        final parsed = Uri.parse(raw);
        var path = parsed.path;
        if (path.endsWith('.svg')) {
          path = '${path.substring(0, path.length - 4)}.png';
        } else if (!path.endsWith('.png')) {
          path = '$path.png';
        }
        return parsed
            .replace(scheme: 'https', host: 'raster.shields.io', path: path)
            .toString();
      } catch (_) {}
    }
    return raw;
  }

  Widget _altFallback() {
    if (alt != null && alt!.isNotEmpty) {
      return Text(
        alt!,
        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = uri.toString();
    final url = _resolveUrl(rawUrl);
    if (!isSafeMarkdownImageUrl(url)) {
      return _altFallback();
    }
    final lower = url.toLowerCase();
    final isShields = rawUrl.contains('shields.io');
    final isSvg =
        !isShields && (lower.contains('.svg') || url.contains('badgen.net'));
    final isBadge = isShields || isSvg || url.contains('badge');
    final imageHeight = isBadge ? 20.0 : _markdownImageMaxHeight;

    Widget imageWidget;
    if (isSvg) {
      imageWidget = SvgPicture.network(
        url,
        height: imageHeight,
        fit: BoxFit.contain,
        placeholderBuilder: (_) =>
            SizedBox(width: isBadge ? 60 : 20, height: 20),
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: url,
        height: isBadge ? 20 : null,
        fit: BoxFit.contain,
        placeholder: (_, _) => SizedBox(width: isBadge ? 60 : 20, height: 20),
        errorWidget: (_, _, _) => _altFallback(),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 2.0,
        vertical: isBadge ? 2.0 : 4.0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isBadge ? 3.0 : AppTheme.radiusSm),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: imageHeight,
            maxWidth: isBadge ? 120 : 360,
          ),
          child: imageWidget,
        ),
      ),
    );
  }
}
