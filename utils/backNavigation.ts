/**
 * 设置页等二级页面的返回逻辑。
 *
 * ## 为什么需要它
 *
 * expo-router / react-navigation 在 **Android TV** 上的默认返回不生效：
 * 栈可能不可回退，而 TV 固件也不会触发默认的 Activity 行为，
 * 结果按返回键毫无反应，只能杀进程重进。
 *
 * 所以页面要自己注册 `BackHandler`（Android 上后注册者优先），
 * 并在这里统一「回退 / 回首页」的决策：
 *
 * - 能回退 → `router.back()`（回到上一页）
 * - 回退不了 → `router.replace("/")`（直接回首页，不留空栈）
 *
 * 抽成纯函数是为了能脱离 React 单独测。
 */

import { Platform } from "react-native";

export interface BackCapableRouter {
  back?: () => void;
  replace?: (href: string) => void;
  navigate?: (href: string) => void;
  canGoBack?: () => boolean;
  /** expo-router v3：清空整个栈回到根路由（TV 上最可靠）。 */
  dismissAll?: () => void;
}

/**
 * 离开当前二级页面。
 *
 * @returns 实际执行的动作：`"back"` | `"replace"` | `"none"`
 */
export function goBackSafely(
  router: BackCapableRouter | undefined | null
): "back" | "replace" | "dismissAll" | "none" {
  if (!router) return "none";
  try {
    // ★ Android TV 上 `router.back()` / `router.replace("/")` 都可能**没反应** ——
    // canGoBack() 说是 true，实际 back() 什么也不做，页面纹丝不动。
    // 实测在 VIDAA 上 replace("/") 同样静默失效。
    //
    // expo-router v3 的 `dismissAll()` 才是 TV 上最可靠的：
    // 直接清空整个导航栈回到根路由，不依赖栈状态。
    if (Platform.isTV) {
      if (typeof router.dismissAll === "function") {
        router.dismissAll();
        return "dismissAll";
      }
      router.replace?.("/");
      return "replace";
    }
    if (typeof router.canGoBack === "function" && router.canGoBack()) {
      router.back?.();
      return "back";
    }
    router.replace?.("/");
    return "replace";
  } catch {
    // 任何异常都退化成「回首页」，保证用户一定能离开这个页面。
    try {
      router.replace?.("/");
      return "replace";
    } catch {
      return "none";
    }
  }
}
