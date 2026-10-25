import React, { useCallback, useMemo, useRef, useState } from "react";
import { SettingsFocusContext, FocusNode } from "@/hooks/useSettingsFocus";

/**
 * 设置页焦点注册表实现。
 *
 * 用 ref 保存节点顺序，避免每次注册触发重渲染；
 * 顺序按注册先后（区块渲染顺序即视觉顺序）。
 */
export function useSettingsFocusRegistry() {
  const nodesRef = useRef<FocusNode[]>([]);
  const [, forceRender] = useState(0);

  const register = useCallback((node: FocusNode) => {
    const list = nodesRef.current;
    const idx = list.findIndex((n) => n.key === node.key);
    if (idx >= 0) {
      list[idx] = node;
    } else {
      list.push(node);
    }
    forceRender((v) => v + 1);
  }, []);

  const unregister = useCallback((key: string) => {
    nodesRef.current = nodesRef.current.filter((n) => n.key !== key);
    forceRender((v) => v + 1);
  }, []);

  const focusAt = useCallback((index: number) => {
    const list = nodesRef.current;
    if (list.length === 0) return false;
    const target = list[Math.max(0, Math.min(index, list.length - 1))];
    if (!target) return false;
    target.focus();
    return true;
  }, []);

  const indexOf = useCallback((key?: string) => {
    if (!key) return -1;
    return nodesRef.current.findIndex((n) => n.key === key);
  }, []);

  /** 按稳定 key 聚焦（设置页按视觉顺序显式驱动时使用） */
  const focusKey = useCallback((key: string) => {
    const node = nodesRef.current.find((n) => n.key === key);
    if (!node) return false;
    node.focus();
    return true;
  }, []);

  const value = useMemo(
    () => ({
      register,
      unregister,
      focusKey,
      focusNext: (currentKey?: string) => {
        const i = indexOf(currentKey);
        if (i < 0) return focusAt(0);
        return focusAt(i + 1);
      },
      focusPrev: (currentKey?: string) => {
        const i = indexOf(currentKey);
        if (i < 0) return focusAt(0);
        return focusAt(i - 1);
      },
      focusFirst: () => focusAt(0),
    }),
    [register, unregister, focusAt, indexOf, focusKey]
  );

  // ★ 返回值必须 memo 化。
  //
  // 之前每次渲染都返回**新对象** `{ value, nodesRef }`，
  // 于是依赖它的 useCallback（moveFocus / activateCurrent / handleTVEvent）
  // 也每次都变 —— 而 RN TV 的 `useTVEventHandler` 的依赖是 `[handleEvent]`：
  //
  //   const useTVEventHandler = (handleEvent) => {
  //     React.useEffect(() => { ...addListener... }, [handleEvent]);
  //   };
  //
  // 也就是说 **handler 一变就重新订阅一次原生 TV 事件**。
  // handler 每次渲染都变 → 每次渲染都订阅+退订原生模块 →
  // 原生侧反复调用 → 电视上直接**卡死**（设置页点开后界面冻结）。
  return React.useMemo(() => ({ value, nodesRef }), [value]);
}
