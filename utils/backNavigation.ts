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

export interface BackCapableRouter {
  back?: () => void;
  replace?: (href: string) => void;
  canGoBack?: () => boolean;
}

/**
 * 离开当前二级页面。
 *
 * @returns 实际执行的动作：`"back"` | `"replace"` | `"none"`
 */
export function goBackSafely(router: BackCapableRouter | undefined | null): "back" | "replace" | "none" {
  if (!router) return "none";
  try {
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
