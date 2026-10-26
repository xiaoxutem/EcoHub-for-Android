/**
 * 从设置页「回首页」用的中转页。
 *
 * ## 为什么绕这一圈
 *
 * 这台电视（VIDAA / Android 6 / react-native-screens 3.31）上，
 * **回到已在导航栈里的路由**这个动作会静默失效：
 * `back()` / `replace("/")` / `dismissAll()` / `navigate("/")` /
 * `<Link href="/">` / `push("/")` —— 全部不报错也不跳转；
 * 而「push 一个**不在栈里**的路由」是**有效**的。
 *
 * 所以这里不去「导航」到首页，而是**直接渲染首页组件**：
 * 绕开所有导航 API，100% 可靠。
 */
import React from "react";
import HomeScreen from "./index";

export default function HomeFromSettings() {
  return <HomeScreen />;
}
