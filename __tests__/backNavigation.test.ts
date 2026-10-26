/**
 * 二级页面返回逻辑（VIDAA TV 真机问题）。
 *
 * 真机表现：打开设置页后按返回键**毫无反应**，只能杀进程重进。
 * 根因：expo-router / react-navigation 在 Android TV 上的默认返回不生效，
 * 页面必须自己注册 `BackHandler` 并决定「回退 / 回首页」。
 */

import { goBackSafely } from "../utils/backNavigation";

describe("goBackSafely", () => {
  it("能回退时调用 back()", () => {
    const back = jest.fn();
    const replace = jest.fn();
    const r = goBackSafely({ back, replace, canGoBack: () => true });
    expect(r).toBe("back");
    expect(back).toHaveBeenCalled();
    expect(replace).not.toHaveBeenCalled();
  });

  it("回退不了时 replace('/') 回首页", () => {
    const back = jest.fn();
    const replace = jest.fn();
    const r = goBackSafely({ back, replace, canGoBack: () => false });
    expect(r).toBe("replace");
    expect(replace).toHaveBeenCalledWith("/");
    expect(back).not.toHaveBeenCalled();
  });

  it("没有 canGoBack 时（老版本 router）也回首页", () => {
    const back = jest.fn();
    const replace = jest.fn();
    const r = goBackSafely({ back, replace });
    expect(r).toBe("replace");
    expect(replace).toHaveBeenCalledWith("/");
  });

  it("router 为空时安全返回 none（不抛）", () => {
    expect(goBackSafely(undefined)).toBe("none");
    expect(goBackSafely(null)).toBe("none");
  });

  it("back() 抛异常时退化成回首页，保证一定能离开页面", () => {
    const replace = jest.fn();
    const r = goBackSafely({
      back: () => {
        throw new Error("boom");
      },
      replace,
      canGoBack: () => true,
    });
    expect(r).toBe("replace");
    expect(replace).toHaveBeenCalledWith("/");
  });
});
