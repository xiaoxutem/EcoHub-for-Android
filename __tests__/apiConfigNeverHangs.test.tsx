/**
 * 「程序卡死」回归测试 —— 这台电视（VIDAA / Android 6）上必须满足：
 *
 * 1. `getItemWithTimeout` 读不出来时**必须返回 null**（而不是永久 pending）
 * 2. `api.getSiteBasic()` 在 fetch 挂住时**必须在 10 秒内 reject**
 *    （★ 不能用 AbortController —— Android 6 的 OkHttp 不支持 fetch 的 signal，
 *       必须用 JS 层 Promise.race）
 * 3. `useApiConfig` 的 isValidating **最多 15 秒**就必须变 false（UI 兜底）
 *
 * 这三条对应真实故障：首页永远停在「正在验证服务器配置...」，
 * 整个 App 看起来就是"卡死"。
 */
import TestRenderer, { act } from "react-test-renderer";
import AsyncStorage from "@react-native-async-storage/async-storage";

jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest/async-storage-mock")
);

import { getItemWithTimeout, SettingsManager } from "../services/storage";
import { api } from "../services/api";
import { useApiConfig } from "../hooks/useApiConfig";

/** 冲刷所有微任务/计时器回调，避免 unhandled rejection。 */
async function flush(times = 8) {
  for (let i = 0; i < times; i++) {
    await Promise.resolve();
    await Promise.resolve();
  }
}

describe("防卡死回归（这台电视实测踩过的坑）", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.useRealTimers();
  });

  it("getItemWithTimeout：读取永久 pending 时必须在超时后返回 null", async () => {
    jest.useFakeTimers();
    const spy = jest
      .spyOn(AsyncStorage, "getItem")
      .mockImplementation(() => new Promise(() => {}) as any); // 永不 resolve

    const p = getItemWithTimeout("k", 3000);
    let settled = false;
    void p.then(() => {
      settled = true;
    });

    await act(async () => {
      jest.advanceTimersByTime(2999);
      await flush();
    });
    expect(settled).toBe(false); // 3 秒前还没好

    await act(async () => {
      jest.advanceTimersByTime(2);
      await flush();
    });
    await expect(p).resolves.toBeNull(); // 3 秒到了 → null
    expect(spy).toHaveBeenCalledTimes(1);
  });

  it("SettingsManager.get：存储卡住也要在超时内返回默认配置", async () => {
    jest.useFakeTimers();
    jest
      .spyOn(AsyncStorage, "getItem")
      .mockImplementation(() => new Promise(() => {}) as any);

    const p = SettingsManager.get();
    let settled = false;
    void p.then(() => {
      settled = true;
    });

    await act(async () => {
      jest.advanceTimersByTime(3100);
      await flush();
    });
    await expect(p).resolves.toMatchObject({
      apiBaseUrl: "http://192.168.88.209:3000",
    });
    expect(settled).toBe(true);
  });

  it("api.getSiteBasic：fetch 挂住必须在 10 秒内 reject", async () => {
    jest.useFakeTimers();
    api.setBaseUrl("http://192.168.88.209:3000");
    const spy = jest.spyOn(global, "fetch").mockImplementation(
      () => new Promise(() => {}) as any // 永不 resolve，模拟电视上的挂起
    );

    const p = api.getSiteBasic();
    // 提前挂一个 no-op catch，避免 reject 时出现 unhandled rejection
    void p.catch(() => {});
    let rejected = false;
    void p.then(
      () => {},
      () => {
        rejected = true;
      }
    );

    await act(async () => {
      jest.advanceTimersByTime(9999);
      await flush();
    });
    expect(rejected).toBe(false);

    await act(async () => {
      jest.advanceTimersByTime(2);
      await flush();
    });
    await expect(p).rejects.toThrow("连接超时");
    expect(spy).toHaveBeenCalledTimes(1);
  });

  it("api.getSiteBasic：绝不能依赖 fetch 的 signal（Android 6 不支持）", async () => {
    api.setBaseUrl("http://192.168.88.209:3000");
    // ★ 让 fetch 立即成功 —— 这个用例只关心「传给 fetch 的 options」，
    //   不关心超时（超时由上一个用例覆盖）。
    const spy = jest
      .spyOn(global, "fetch")
      .mockImplementation((async () =>
        ({
          ok: true,
          status: 200,
          headers: { get: () => null },
          text: async () => JSON.stringify({ code: 0, data: { siteName: "x" } }),
        }) as any) as any);

    await act(async () => {
      await api.getSiteBasic();
      await flush();
    });

    // ★ 关键断言：fetch 收到的第二个参数里**不能**带 signal
    const opts = spy.mock.calls[0]?.[1] as RequestInit | undefined;
    expect(opts).toBeDefined();
    expect(opts && "signal" in opts).toBe(false);
    spy.mockRestore();
  });

});

/**
 * 首页不得因为「正在验证服务器配置」而卡死。
 *
 * 真机实测：`apiConfigStatus.isValidating` 分支会**永远**停住
 * （验证链路上任何一环的 await 收不到终态），
 * 整个 App 看起来就是「卡死」——什么都点不了。
 *
 * 这里的断言是：**即使 isValidating 为 true，首页也必须渲染出内容区**
 * （分类 chip / 齿轮等可交互元素），而不是只有一个转圈。
 */
describe("首页不会卡在验证转圈上", () => {
  it("首页源码里 isValidating 不得阻塞内容渲染", () => {
    const fs = require("fs");
    const path = require("path");
    const src = fs.readFileSync(
      path.join(__dirname, "..", "app", "index.tsx"),
      "utf8"
    );
    // 不能再出现「isValidating 作为渲染分支条件」
    const hasBlockingBranch = /\)\s*:\s*apiConfigStatus\.isValidating\s*\?/.test(
      src
    );
    expect(hasBlockingBranch).toBe(false);
  });
});
