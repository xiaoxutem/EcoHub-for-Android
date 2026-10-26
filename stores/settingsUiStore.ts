/**
 * 设置页覆盖层的**显示状态**。
 *
 * ## 为什么是「覆盖层」而不是独立路由
 *
 * 这台电视（VIDAA / Android 6 / react-native-screens 3.31）上，
 * **回到已在导航栈里的路由**这个动作会静默失效：
 * `router.push('/')` / `back()` / `replace('/')` / `dismissAll()` /
 * `navigate('/')` / `<Link href="/">` —— 全部不报错也不跳转；
 * 连底部导航「首页」tab（也是 `router.push('/')`）都同样失效。
 * （参考 Flutter 原版：它用**纯 Dart 的 Navigator** 自维护页面栈，所以没这问题。）
 *
 * ⇒ 打开/关闭设置页只能走**纯 JS 状态**，完全不碰导航栈。
 *
 * ## 为什么显隐用 Animated.Value 而不是 useState
 *
 * 显隐交给 Animated（命令式，直接写原生属性），
 * 这样「显示」不依赖任何 React 重绘时机，最稳；
 * 而 React 侧只需要一个 `open` 布尔值来控制 pointerEvents / 焦点。
 */
import { Animated } from "react-native";
import { create } from "zustand";

/** 覆盖层显隐动画（模块级单例，首页与设置页共用）。 */
export const settingsOverlayOpacity = new Animated.Value(0);

interface SettingsUiState {
  open: boolean;
  show: () => void;
  hide: () => void;
}

export const useSettingsUiStore = create<SettingsUiState>((set) => ({
  open: false,
  show: () => {
    set({ open: true });
    Animated.timing(settingsOverlayOpacity, {
      toValue: 1,
      duration: 160,
      useNativeDriver: false,
    }).start();
  },
  hide: () => {
    set({ open: false });
    Animated.timing(settingsOverlayOpacity, {
      toValue: 0,
      duration: 160,
      useNativeDriver: false,
    }).start();
  },
}));
