/**
 * Below are the colors that are used in the app. The colors are defined in the light and dark mode.
 * There are many other ways to style your app. For example, [Nativewind](https://www.nativewind.dev/), [Tamagui](https://tamagui.dev/), [unistyles](https://reactnativeunistyles.vercel.app), etc.
 */

const tintColorLight = "#0a7ea4";
const tintColorDark = "#aaa";

export const Colors = {
  light: {
    text: "#11181C",
    background: "#fff",
    tint: tintColorLight,
    icon: "#687076",
    tabIconDefault: "#687076",
    tabIconSelected: tintColorLight,
    link: "#0a7ea4",
    border: "#E5E5E5",
  },
  dark: {
    text: "#ECEDEE",
    background: "#151718",
    tint: tintColorDark,
    icon: "#9BA1A6",
    tabIconDefault: "#9BA1A6",
    tabIconSelected: tintColorDark,
    link: "#0a7ea4",
    border: "#333",
    /**
     * 主色 = **橙色**。
     *
     * 原来这里是绿色 `#00bb5e`（按钮选中态绿 + 焦点框绿）。
     * 电视上绿色边框在深色背景里不够醒目，容易和「选中态」混淆 ——
     * 用户明确要求**橙色高亮框**。
     *
     * 与 Flutter 版保持一致（AppTheme.accent = #FA8C16）。
     */
    primary: "#FA8C16",
    /** 焦点框颜色（与主色一致）。 */
    focus: "#FA8C16",
  },
};
