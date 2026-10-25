import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/app_theme.dart';
import 'focus_wrap.dart';

/// 电视端软键盘面板。
///
/// 为什么需要它：很多 Android TV 定制系统（如 VIDAA / 海信）**不提供 TV 版软键盘面板**，
/// `TextInput.show` 只会把 IME 标记为「已请求」但界面不弹出，
/// 用户因此完全无法在输入框里打字 —— 这是 TV 上最常见的输入障碍。
///
/// 本组件提供应用内自绘的键盘，遥控器可逐键选择，不依赖系统输入法。
///
/// 布局：
/// - 第一行：常用符号（`/` `.` `:` `-` `_` `?` `=` `&`）
/// - 第二行：数字 1-9
/// - 第三行：`0` + 退格 + 空格
/// - 第四行：字母（分三组循环切换，电视上比 26 键全排更实用）
class TvKeyboardPanel extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onDone;
  final ValueChanged<String>? onChanged;

  const TvKeyboardPanel({
    super.key,
    required this.controller,
    this.onDone,
    this.onChanged,
  });

  @override
  State<TvKeyboardPanel> createState() => _TvKeyboardPanelState();
}

class _TvKeyboardPanelState extends State<TvKeyboardPanel> {
  /// 字母分组：0 = 小写 a-z，1 = 大写 A-Z
  int _letterGroup = 0;

  static const List<List<String>> _symbolRows = [
    ['/', '.', ':', '-', '_', '?', '=', '&'],
    ['@', '#', '%', '+', '*', ',', '~'],
  ];

  static final List<String> _letters = 'abcdefghijklmnopqrstuvwxyz'.split('');

  void _insert(String text) {
    final value = widget.controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final newText = value.text.replaceRange(start, end, text);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    widget.onChanged?.call(newText);
  }

  /// 退格。
  ///
  /// 电视上没有可见的文本光标，用户无法判断插入点在哪，
  /// 「删光标前一个」会让人困惑。这里采用电视键盘的通用做法：
  /// **始终删除最后一个字符**，并把光标移到末尾。
  ///
  /// 例外：光标确实在末尾时行为一致（同样删最后一个）。
  void _backspace() {
    final value = widget.controller.value;
    if (value.text.isEmpty) return;
    final newText = value.text.substring(0, value.text.length - 1);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    widget.onChanged?.call(newText);
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final letters = _letterGroup == 0 ? _letters : _letters.map((e) => e.toUpperCase()).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TV 上没有可见的文本光标（无 IME 输入视图），
          // 用户不知道当前输入到哪里。这里用一条高亮预览带明确指示。
          _buildPreview(),
          const SizedBox(height: 8),
          for (final row in _symbolRows) ...[
            _buildRow(row),
            const SizedBox(height: 6),
          ],
          _buildRow(['1', '2', '3', '4', '5', '6', '7', '8', '9']),
          const SizedBox(height: 6),
          // 用图标代替文字，避免汉字在窄格里被压缩导致字形错位。
          _buildRow([
            '0',
            '⌫',
            '␣',
            '✕',
          ], actionKeys: const {1, 2, 3}),
          const SizedBox(height: 6),
          _buildRow(letters.sublist(0, 13)),
          const SizedBox(height: 6),
          _buildRow([
            ...letters.sublist(13, 26),
            // 用「Aa」而不是「大小写」——
            // 三个汉字在等分的窄格子里会被压缩，字形挤在一起显得错位。
            _letterGroup == 0 ? 'Aa' : 'aA',
            '完成',
          ], actionKeys: const {13, 14}),
        ],
      ),
    );
  }

  /// 输入预览带：显示当前文本，并在末尾画一个闪烁的插入指示块。
  Widget _buildPreview() {
    final text = widget.controller.text;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text.isEmpty ? '请用下方键盘输入' : text,
              style: TextStyle(
                fontSize: 15,
                color: text.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary,
              ),
            ),
            if (text.isNotEmpty)
              Container(
                width: 2,
                height: 18,
                margin: const EdgeInsets.only(left: 2),
                color: AppTheme.accent,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys, {Set<int> actionKeys = const {}}) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          Expanded(
            child: _buildKey(keys[i], isAction: actionKeys.contains(i)),
          ),
          if (i != keys.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }

  /// 是否是符号类键（用图标，字体略大一些更清晰）。
  static bool _isSymbolKey(String label) {
    return label == '⌫' || label == '␣' || label == '✕' ||
        label == 'Aa' || label == 'aA';
  }

  Widget _buildKey(String label, {bool isAction = false}) {
    VoidCallback? onTap;
    switch (label) {
      case '⌫':
        onTap = _backspace;
        break;
      case '␣':
        onTap = () => _insert(' ');
        break;
      case '✕':
        onTap = _clear;
        break;
      case 'Aa':
      case 'aA':
        onTap = () => setState(() => _letterGroup = _letterGroup == 0 ? 1 : 0);
        break;
      case '完成':
        onTap = () {
          widget.onDone?.call();
          // 同时把系统 IME 收起来，避免与面板叠加。
          SystemChannels.textInput.invokeMethod<void>('TextInput.hide').catchError((_) {});
        };
        break;
      default:
        onTap = () => _insert(label);
    }

    return FocusTap(
      onTap: onTap,
      focusRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isAction ? AppTheme.accentSoft : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: _isSymbolKey(label) ? 17 : 15,
            fontWeight: isAction ? FontWeight.w600 : FontWeight.w400,
            color: isAction ? AppTheme.accent : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
