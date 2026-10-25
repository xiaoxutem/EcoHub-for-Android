import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/tv_mode.dart';

/// 电视友好的输入框。
///
/// 解决两个在 Android TV 上非常常见的问题：
///
/// 1. **输入法不弹出。**
///    Android TV 的软键盘默认不自动跟随焦点变化 —— 遥控器把焦点移到
///    `TextField` 后键盘不一定弹出，用户无法输入。
///    这里在获得焦点时显式调用 `TextInput.show` 主动拉起 IME。
///
/// 2. **看不出焦点在哪。**
///    `TextField` 自带的高亮在电视上几乎不可见，
///    这里额外画一圈明显的焦点框。
///
/// 非 TV 平台退化为原生 [TextField]，行为完全不变。
class TvTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final Color cursorColor;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  /// 焦点框颜色，默认主题橙色。
  final Color? focusColor;

  /// 焦点框圆角。
  final BorderRadius? focusRadius;

  const TvTextField({
    super.key,
    this.controller,
    this.hintText,
    this.style,
    this.hintStyle,
    this.cursorColor = const Color(0xFFFA8C16),
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.focusColor,
    this.focusRadius,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  late final FocusNode _node;
  bool _focused = false;
  bool _ownsNode = false;

  @override
  void initState() {
    super.initState();
    _ownsNode = widget.focusNode == null;
    _node = widget.focusNode ?? FocusNode(debugLabel: 'TvTextField');
    _node.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_handleFocus);
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (!mounted) return;
    final focused = _node.hasFocus;
    if (focused != _focused) {
      setState(() => _focused = focused);
    }
    if (focused) {
      // 延迟一帧再拉起键盘：此时 Flutter 的 TextInput 通道已就绪。
      WidgetsBinding.instance.addPostFrameCallback((_) => _showKeyboard());
    }
  }

  void _showKeyboard() {
    if (!mounted || !_node.hasFocus) return;
    // Android TV 上软键盘不会随焦点自动弹出，必须显式请求。
    // 部分电视系统没有 IME，此时调用静默失败即可。
    SystemChannels.textInput.invokeMethod<void>('TextInput.show').catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: widget.controller,
      focusNode: _node,
      style: widget.style,
      cursorColor: widget.cursorColor,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: widget.hintStyle,
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );

    if (!TvMode.isTvActive) return field;

    final color = widget.focusColor ?? const Color(0xFFFA8C16);
    final radius = widget.focusRadius ?? BorderRadius.circular(8);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        field,
        if (_focused)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: color, width: TvMode.focusBorderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
