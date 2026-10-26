/**
 * `/api/session/status` 返回 404 时的行为。
 *
 * ## 背景
 *
 * 较早的自建 CMS 源**没有** `/api/session/status` 这个接口，
 * 直接访问会 404。而 404 ≠「需要登录」——
 * 它只说明「这个源没有门禁探测接口」。
 *
 * 如果把 404 当成需要登录：游客明明能正常浏览（/api/index 返回 200），
 * App 打开却先弹登录框 —— 而电视上没有系统 IME，用户根本没法登录。
 *
 * 真实故障：`panghuFetch` 抛的是 `new Error("HTTP error! status: 404")`，
 * 状态码只在 message 字符串里、没有 `status` 字段，
 * 于是按 `e.status === 404` 判断的容错逻辑**永远不生效**。
 */

jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest/async-storage-mock")
);

import { API } from "../services/api";

describe("session/status 404 容错", () => {
  it("404 → 视为「不要求登录」，而不是抛错", async () => {
    const api = new API();
    api.setBaseUrl("http://s");

    (global as any).fetch = jest.fn(async () => ({
      ok: false,
      status: 404,
      headers: { get: () => null },
      text: async () => "404 page not found",
    }));

    const status = await api.getSessionStatus();
    expect(status.requireWebLogin).toBe(false);
    expect(status.authenticated).toBe(false);
  });

  it("抛出的 HTTP 错误带 status 字段（可被调用方直接判断）", async () => {
    const api = new API();
    api.setBaseUrl("http://s");

    (global as any).fetch = jest.fn(async () => ({
      ok: false,
      status: 500,
      headers: { get: () => null },
      text: async () => "boom",
    }));

    await expect(api.getSessionStatus()).rejects.toMatchObject({ status: 500 });
  });
});
