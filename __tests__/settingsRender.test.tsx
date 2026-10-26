/**
 * 设置页渲染复现测试。
 *
 * ## 为什么要这个测试
 *
 * 真机上表现为：点右上角齿轮 → **程序卡死**（界面冻结）。
 * React 里「渲染函数里 setState」与「useEffect 依赖不稳定」都会触发
 * `Maximum update depth exceeded` 或无限重渲染 —— 二者在 TV 上都表现为卡死。
 *
 * 这个测试把设置页渲染起来，并统计渲染次数：
 * 渲染次数失控（> 50）即判定为死循环。
 */

jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest/async-storage-mock")
);

// expo-router：设置页用到 useRouter
const mockRouter = {
  push: jest.fn(),
  back: jest.fn(),
  replace: jest.fn(),
  setParams: jest.fn(),
  navigate: jest.fn(),
  canGoBack: jest.fn(() => true),
};

jest.mock("expo-router", () => ({
  useRouter: () => mockRouter,
  usePathname: () => "/settings",
  useSegments: () => [],
  useLocalSearchParams: () => ({}),
  Link: ({ children }: any) => children,
  // useFocusEffect：expo-router v3 从 react-navigation 转发而来
  useFocusEffect: (cb: any) => {
    const React = require("react");
    React.useEffect(() => cb(), [cb]);
  },
}));

// Toast
jest.mock("react-native-toast-message", () => ({
  __esModule: true,
  default: { show: jest.fn() },
  show: jest.fn(),
}));

// 键盘滚动容器：原生模块在 jest 下不可用
jest.mock("react-native-keyboard-aware-scroll-view", () => {
  const React = require("react");
  const { View } = require("react-native");
  return {
    __esModule: true,
    default: ({ children, ...rest }: any) => React.createElement(View, rest, children),
    KeyboardAwareScrollView: ({ children, ...rest }: any) =>
      React.createElement(View, rest, children),
  };
});

// 原生模块：jest 下没有实现
jest.mock("react-native-tcp-socket", () => ({
  __esModule: true,
  default: {
    createServer: jest.fn(() => ({
      listen: jest.fn(),
      close: jest.fn(),
      on: jest.fn(),
      removeAllListeners: jest.fn(),
    })),
    connect: jest.fn(),
  },
  createServer: jest.fn(),
}));

jest.mock("@react-native-community/netinfo", () => ({
  __esModule: true,
  default: {
    fetch: jest.fn(() => Promise.resolve({ isConnected: true, type: "wifi" })),
    addEventListener: jest.fn(() => jest.fn()),
  },
}));

// 安全区：jest 下需要 Provider
jest.mock("react-native-safe-area-context", () => {
  const React = require("react");
  const insets = { top: 0, right: 0, bottom: 0, left: 0 };
  return {
    __esModule: true,
    SafeAreaProvider: ({ children }: any) => React.createElement(React.Fragment, null, children),
    SafeAreaView: ({ children }: any) => React.createElement(React.Fragment, null, children),
    useSafeAreaInsets: () => insets,
    useSafeAreaFrame: () => ({ x: 0, y: 0, width: 1920, height: 1080 }),
    initialWindowMetrics: { frame: { x: 0, y: 0, width: 1920, height: 1080 }, insets },
  };
});

// RN TV 的 TV 事件订阅：jest 下没有原生实现
// TVFocusGuideView：jest 下没有原生实现（setDestinations 命令不存在）。
//
// ★ 它在 RN 里是 **CommonJS 直接导出**（module.exports = ForwardedTVFocusGuideView），
//   RN 的 index.js 用 require() 拿 —— 所以 mock 也必须直接导出组件本身，
//   写成 { __esModule: true, default: C } 会让 RN 拿到一个对象而不是组件，
//   渲染时整个套件直接挂掉。
// ★ 用 Fragment 替身，避免在 mock 工厂里 require("react-native") 造成循环依赖。
jest.mock("react-native/Libraries/Components/TV/TVFocusGuideView", () => {
  const React = require("react");
  return function TVFocusGuideViewStub({ children }: any) {
    return React.createElement(React.Fragment, null, children);
  };
});

// 统计原生 TV 事件订阅次数 —— 这是「卡死」的直接指标。
//
// RN TV 的 useTVEventHandler 依赖 `[handleEvent]`：
// handler 每次渲染都变 → 每次渲染都 addListener/remove 一次原生模块 →
// 原生侧反复调用 → 电视上界面冻结。
let tvSubscribeCount = 0;

// 电视尺寸（1920x1080）—— 让 useResponsiveLayout 判定为 'tv'，
// 走的是 `handleTVEvent` 那条分支（与真机一致）。
jest.mock("react-native/Libraries/Utilities/Dimensions", () => {
  const actual = jest.requireActual("react-native/Libraries/Utilities/Dimensions");
  return {
    ...actual,
    get: () => ({ width: 1920, height: 1080, scale: 1, fontScale: 1 }),
    addEventListener: () => ({ remove: () => {} }),
    removeEventListener: () => {},
  };
});

// ★ RN 的 TVEventHandler 是 CommonJS 直接导出对象（module.exports = {...}），
//   不是 ESM default —— mock 形态必须一致，否则 `addListener is not a function`。
jest.mock("react-native/Libraries/Components/TV/TVEventHandler", () => ({
  addListener: () => {
    tvSubscribeCount += 1;
    return { remove: () => {} };
  },
  removeAllListeners: () => {},
}));

jest.mock("expo-constants", () => ({
  __esModule: true,
  default: { manifest: { extra: {} }, executionEnvironment: "standalone" },
  Constants: { manifest: { extra: {} } },
}));

import React from "react";
import TestRenderer, { act } from "react-test-renderer";
import SettingsScreen from "../app/settings";

describe("设置页渲染（不卡死）", () => {
  beforeEach(() => {
    mockRouter.push.mockClear();
    mockRouter.back.mockClear();
    mockRouter.replace.mockClear();
    mockRouter.canGoBack.mockReturnValue(true);
  });

  it("渲染设置页不应陷入无限重渲染", async () => {
    // 统计 SettingsScreen 自身的渲染次数
    let renderCount = 0;

    // 包一层计数包装
    const Counting = (props: any) => {
      renderCount += 1;
      return React.createElement(SettingsScreen, props);
    };

    // 计时器推进（设置页有 400ms 的初始聚焦定时器）
    jest.useFakeTimers();

    let tree: any = null;
    await act(async () => {
      tree = TestRenderer.create(React.createElement(Counting));
      // 推进定时器若干轮
      for (let i = 0; i < 20; i++) {
        jest.advanceTimersByTime(500);
      }
    });

    // eslint-disable-next-line no-console
    console.log(`[设置页] 渲染次数 = ${renderCount}，原生 TV 事件订阅次数 = ${tvSubscribeCount}`);

    expect(renderCount).toBeLessThan(50);
    // 原生 TV 事件订阅应当只发生一次（handler 稳定）。
    // 之前 handler 每次渲染都变 → 订阅次数跟着暴涨 → 电视上卡死。
    expect(tvSubscribeCount).toBeLessThanOrEqual(3);

    // 设置页**真的渲染出内容**（不只是没死循环）。
    // 标题「设置」与 API 地址区块都应该在。
    const text = JSON.stringify(tree.toJSON());
    expect(text).toContain("设置");
    expect(text).toContain("API");

    await act(async () => {
      tree.unmount();
    });
    jest.useRealTimers();
  }, 30000);

  // ─────────────────────────────────────────────────────────────
  // 下面两个是 VIDAA TV 真机上发现的两个问题：
  //   ① 设置页按返回键回不去首页
  //   ② 设置页里看不到任何橙色焦点框
  // ─────────────────────────────────────────────────────────────

  it("页面上存在可聚焦控件（TV 焦点必须有落点）", async () => {
    let tree: any = null;
    await act(async () => {
      tree = TestRenderer.create(React.createElement(SettingsScreen));
    });
    // 找到带 focusable 的控件 —— 没有可聚焦控件，原生焦点系统就没有落点，
    // 方向键会「哪都不去」，表现就是看不到任何焦点框。
    const focusables = tree.root.findAll(
      (n: any) => n.props && n.props.focusable === true,
      { deep: true }
    );
    expect(focusables.length).toBeGreaterThan(0);
    await act(async () => {
      tree.unmount();
    });
  });
});
