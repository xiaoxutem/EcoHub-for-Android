import React, { useState, useEffect, useRef } from "react";
import { View, StyleSheet, Alert, Platform, ScrollView, useTVEventHandler, Pressable, BackHandler, ToastAndroid } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { ThemedText } from "@/components/ThemedText";
import { Colors } from "@/constants/Colors";
import { goBackSafely } from "@/utils/backNavigation";
import { ThemedView } from "@/components/ThemedView";
import { StyledButton } from "@/components/StyledButton";
import { useThemeColor } from "@/hooks/useThemeColor";
import { useSettingsStore } from "@/stores/settingsStore";
import useAuthStore from "@/stores/authStore";
import { useRemoteControlStore } from "@/stores/remoteControlStore";
import { CommonActions, useNavigation } from "@react-navigation/native";
import { APIConfigSection } from "@/components/settings/APIConfigSection";
import { AccountSection } from "@/components/settings/AccountSection";
import { LiveStreamSection } from "@/components/settings/LiveStreamSection";
import { RemoteInputSection } from "@/components/settings/RemoteInputSection";
import { UpdateSection } from "@/components/settings/UpdateSection";
// import { VideoSourceSection } from "@/components/settings/VideoSourceSection";
import Toast from "react-native-toast-message";
import { useResponsiveLayout } from "@/hooks/useResponsiveLayout";
import { getCommonResponsiveStyles } from "@/utils/ResponsiveStyles";
import ResponsiveNavigation from "@/components/navigation/ResponsiveNavigation";
import ResponsiveHeader from "@/components/navigation/ResponsiveHeader";
import { DeviceUtils } from "@/utils/DeviceUtils";
import { KeyboardAwareScrollView } from 'react-native-keyboard-aware-scroll-view';
import { SettingsFocusContext } from "@/hooks/useSettingsFocus";
import { useSettingsFocusRegistry } from "@/hooks/useSettingsFocusRegistry";
import {useFocusEffect, usePathname, useRouter} from "expo-router";

type SectionItem = {
  component: React.ReactElement;
  key: string;
};

/** 过滤掉 false/undefined，帮 TypeScript 推断出真正的数组元素类型 */
function isSectionItem(
  item: false | undefined | SectionItem
): item is SectionItem {
  return !!item;
}

export default function SettingsScreen() {
  const router = useRouter();
  const { loadSettings, saveSettings, saveAccountAndLogin, setApiBaseUrl, setM3uUrl } = useSettingsStore();
  const { lastMessage, targetPage, clearMessage } = useRemoteControlStore();
  const backgroundColor = useThemeColor({}, "background");
  const insets = useSafeAreaInsets();

  // 账号区（API 地址下方）：保存即登录
  const [loginUsername, setLoginUsername] = useState("");
  const [loginPassword, setLoginPassword] = useState("");
  const accountSectionRef = useRef<any>(null);

  // 响应式布局配置
  const responsiveConfig = useResponsiveLayout();
  const commonStyles = getCommonResponsiveStyles(responsiveConfig);
  const { deviceType, spacing } = responsiveConfig;

  const [hasChanges, setHasChanges] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [currentSection, setCurrentSection] = useState<string | null>(null);

  const apiSectionRef = useRef<any>(null);
  const liveStreamSectionRef = useRef<any>(null);
  const saveButtonRef = useRef<any>(null);
  /** 远程输入开关的切换函数（由 RemoteInputSection 注册，供页面级 select 分发调用） */
  const remoteInputToggleRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  useEffect(() => {
    // 只处理「明确指向设置页」的文本（targetPage === 'settings'）。
    // 手机端「发送文本到电视」默认进搜索页，不能被抓来改 API 地址/账号。
    if (lastMessage && targetPage === "settings") {
      const realMessage = lastMessage.split("_")[0];
      handleRemoteInput(realMessage);
      clearMessage(); // Clear the message after processing
      markAsChanged();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lastMessage, targetPage]);

  const handleRemoteInput = (message: string) => {
    // Handle remote input based on currently focused section
    if (currentSection === "api" && apiSectionRef.current) {
      // API Config Section
      setApiBaseUrl(message);
    } else if (currentSection === "username" && accountSectionRef.current) {
      accountSectionRef.current.setUsernameValue(message);
    } else if (currentSection === "password" && accountSectionRef.current) {
      accountSectionRef.current.setPasswordValue(message);
    } else if (currentSection === "livestream" && liveStreamSectionRef.current) {
      // Live Stream Section
      setM3uUrl(message);
    }
  };

  const handleSave = async () => {
    setIsLoading(true);
    try {
      await saveSettings();
      // 账号区非空时保存凭据并立即登录（远程输入一次配好服务器+账号）
      if (loginUsername.trim()) {
        const loginOk = await saveAccountAndLogin(loginUsername, loginPassword);
        if (loginOk) {
          await useAuthStore.getState().checkLoginStatus(useSettingsStore.getState().apiBaseUrl);
        }
        Toast.show({
          type: loginOk ? "success" : "error",
          text1: loginOk ? "已登录" : "登录失败，请检查用户名密码",
        });
      }
      setHasChanges(false);
      Toast.show({
        type: "success",
        text1: "保存成功",
      });
    } catch {
      Alert.alert("错误", "保存设置失败");
    } finally {
      setIsLoading(false);
    }
  };

  const markAsChanged = () => {
    setHasChanges(true);
  };

  /** TV：按 OK 保存设置并退出设置页（返回首页） */
  const handleSaveAndExit = async () => {
    if (isLoading) return;
    if (hasChanges) {
      await handleSave();
    }
    if (router.canGoBack()) {
      router.back();
    } else {
      router.replace("/");
    }
  };

  // const sections = [
  //   // 远程输入配置 - 仅在非手机端显示
  //   deviceType !== "mobile" && {
  //     component: (
  //       <RemoteInputSection
  //         onChanged={markAsChanged}
  //         onFocus={() => {
  //           setCurrentFocusIndex(0);
  //           setCurrentSection("remote");
  //         }}
  //       />
  //     ),
  //     key: "remote",
  //   },
  //   {
  //     component: (
  //       <APIConfigSection
  //         ref={apiSectionRef}
  //         onChanged={markAsChanged}
  //         hideDescription={deviceType === "mobile"}
  //         onFocus={() => {
  //           setCurrentFocusIndex(1);
  //           setCurrentSection("api");
  //         }}
  //       />
  //     ),
  //     key: "api",
  //   },
  //   // 直播源配置 - 仅在非手机端显示
  //   deviceType !== "mobile" && {
  //     component: (
  //       <LiveStreamSection
  //         ref={liveStreamSectionRef}
  //         onChanged={markAsChanged}
  //         onFocus={() => {
  //           setCurrentFocusIndex(2);
  //           setCurrentSection("livestream");
  //         }}
  //       />
  //     ),
  //     key: "livestream",
  //   },
  //   // {
  //   //   component: (
  //   //     <VideoSourceSection
  //   //       onChanged={markAsChanged}
  //   //       onFocus={() => {
  //   //         setCurrentFocusIndex(3);
  //   //         setCurrentSection("videoSource");
  //   //       }}
  //   //     />
  //   //   ),
  //   //   key: "videoSource",
  //   // },
  //   Platform.OS === "android" && {
  //     component: <UpdateSection />,
  //     key: "update",
  //   },
  // ].filter(Boolean);
  const rawSections = [
    deviceType !== "mobile" && {
      component: (
        <RemoteInputSection
          onChanged={markAsChanged}
          onFocus={() => {
            setCurrentSection("remote");
          }}
          onRegisterToggle={(fn: () => void) => {
            remoteInputToggleRef.current = fn;
          }}
        />
      ),
      key: "remote",
    },
    {
      component: (
        <APIConfigSection
          ref={apiSectionRef}
          onChanged={markAsChanged}
          hideDescription={deviceType === "mobile"}
          onFocus={() => {
            setCurrentSection("api");
          }}
        />
      ),
      key: "api",
    },
    {
      component: (
        <AccountSection
          ref={accountSectionRef}
          username={loginUsername}
          password={loginPassword}
          setUsername={(v) => {
            setLoginUsername(v);
            markAsChanged();
          }}
          setPassword={(v) => {
            setLoginPassword(v);
            markAsChanged();
          }}
          onFocus={() => setCurrentSection("username")}
          onBlur={() => setCurrentSection(null)}
        />
      ),
      key: "account",
    },
    deviceType !== "mobile" && {
      component: (
        <LiveStreamSection
          ref={liveStreamSectionRef}
          onChanged={markAsChanged}
          onFocus={() => {
            setCurrentSection("livestream");
          }}
        />
      ),
      key: "livestream",
    },
    Platform.OS === "android" && {
      component: <UpdateSection />,
      key: "update",
    },
  ] as const; // 把每个对象都当作字面量保留
  /** 这里得到的 sections 已经是 SectionItem[]（没有 false） */
  const sections: SectionItem[] = rawSections.filter(isSectionItem);


  // TV 遥控器焦点：设置页控件嵌在 ScrollView + 自定义容器里，原生焦点搜索
  // 拿不到可靠的上下相邻关系；且 TextInput 一旦聚焦会挂输入法吃掉方向键。
  // 因此按「视觉顺序」显式驱动 上/下 键：焦点键序列 + 当前下标。
  const focusRegistry = useSettingsFocusRegistry();
  const focusOrder = React.useMemo(() => {
    const keys: string[] = [];
    if (deviceType !== "mobile") keys.push("settings.remoteInput");
    keys.push("settings.api");
    keys.push("settings.account.username");
    keys.push("settings.account.password");
    if (deviceType !== "mobile") keys.push("settings.liveStream");
    keys.push("settings.save");
    return keys;
  }, [deviceType]);

  const focusIndexRef = useRef(0);
  const [focusReady, setFocusReady] = useState(false);

  // 保存按钮注册进焦点链，否则上/下走到底会落到不存在的节点上
  useEffect(() => {
    focusRegistry.value.register({
      key: "settings.save",
      focus: () => saveButtonRef.current?.focus?.(),
    });
    return () => focusRegistry.value.unregister("settings.save");
  }, [focusRegistry]);

  const moveFocus = React.useCallback(
    (delta: number) => {
      const step = delta > 0 ? 1 : -1;
      let next = focusIndexRef.current;
      // 跳过未注册的节点（mobile 下没有 remoteInput/liveStream，或 UpdateSection 未渲染）
      for (let guard = 0; guard < focusOrder.length; guard++) {
        const candidate = next + step;
        if (candidate < 0 || candidate > focusOrder.length - 1) break;
        next = candidate;
        if (focusRegistry.value.focusKey(focusOrder[next])) break;
      }
      focusIndexRef.current = Math.max(0, Math.min(next, focusOrder.length - 1));
      focusRegistry.value.focusKey(focusOrder[focusIndexRef.current]);
    },
    [focusOrder, focusRegistry]
  );

  // 当前聚焦行的"按下"动作。TV 上 OEM 固件常只发 select 不发 press，
  // 由页面统一分发，避免各区块自己抢事件互相覆盖。
  const activateCurrent = React.useCallback(() => {
    const key = focusOrder[focusIndexRef.current];
    if (key === "settings.remoteInput") {
      focusRegistry.value.focusKey(key);
      // 开关切换由 RemoteInputSection 的注册节点处理
      remoteInputToggleRef.current?.();
      return;
    }
    if (key === "settings.save") {
      void handleSaveAndExit();
      return;
    }
    // 输入框：聚焦即唤起键盘，按 OK 等同聚焦
    focusRegistry.value.focusKey(key);
  }, [focusOrder, focusRegistry]);

  const handleTVEvent = React.useCallback(
    (event: any) => {
      if (deviceType !== "tv") return;
      if (event.eventType === "down" || event.eventType === "up") {
        moveFocus(event.eventType === "down" ? 1 : -1);
        return;
      }
      if (event.eventType === "select" || event.eventType === "playPause") {
        activateCurrent();
      }
    },
    [deviceType, moveFocus, activateCurrent]
  );

  // 非电视端用一个**稳定引用**的空 handler。
  //
  // RN TV 的 `useTVEventHandler` 依赖是 `[handleEvent]` ——
  // 每次渲染传新的函数就会重新订阅一次原生 TV 事件（原生反复调用 → 卡死）。
  // ★ TV 上**不抢**方向键，交给原生焦点系统。
  //
  // 之前是用 useTVEventHandler 拦下 down/up，再靠 `focusRegistry.focusKey(key)`
  // → 区块的 `rowRef.current.focus()` 手动移焦。
  // 但 **RN 的 `Pressable` 是函数组件、不转发 ref** —— `rowRef.current` 永远是 null，
  // `focus?.()` 静默失败。结果：方向键被我们拦住（原生焦点搜索失效），
  // 自己的手动聚焦又无效 → 焦点哪都去不了 → 设置页里看不到任何焦点框。
  //
  // 现在方向键走原生焦点系统（各区块内部控件都带 `focusable`），
  // 焦点落到谁由系统判定，onFocus 回调负责点亮橙色焦点框；
  // select 事件同样交给控件自己的 onPress。
  const noopTVEventHandler = React.useCallback(() => {}, []);
  useTVEventHandler(noopTVEventHandler);

  // 进入页面把焦点放到第一项
  useEffect(() => {
    if (deviceType !== "tv" || focusReady) return;
    const timer = setTimeout(() => {
      // ★ 不再手动调 focusKey() —— 各区块的 rowRef 挂在 Pressable 上（不支持 ref），
      // 手动聚焦从来没生效过。现在靠原生焦点系统自动落到第一个可聚焦控件。
      focusIndexRef.current = 0;
      setFocusReady(true);
    }, 400);
    return () => clearTimeout(timer);
  }, [deviceType, focusReady]);

  // ★ 显式处理返回键。
  //
  // expo-router / react-navigation 在 Android TV 上的默认返回**不生效**
  // （栈可能不可回退，且 TV 固件不会触发默认的 Activity 行为），
  // 结果按返回键毫无反应、只能杀进程重进。
  //
  // 自己在页面级注册 BackHandler（后注册者优先）：
  // 能回退就 back，不能回退就 replace 回首页 —— 保证一定能离开设置页。
  // navigation 在设置页（独立路由）里是有 NavigationContainer 上下文的 ✓
  const navigation = useNavigation();

  const goBack = React.useCallback(() => {
    // ★ 回首页：依次尝试几种方式（这台电视上大部分导航动作都静默失效，
    //   所以每种都试一遍，并用 Toast 报告到底走到哪一步）。
    //
    //   实测失效的：back() / replace("/") / dismissAll() / navigate("/") /
    //                <Link href="/"> / push("/")
    //   实测有效的：push 一个**不在栈里**的路由
    const attempts: Array<[string, () => void]> = [
      ["popToTop", () => (navigation as any)?.popToTop?.()],
      [
        "reset",
        () =>
          (navigation as any)?.dispatch?.(
            CommonActions.reset({ index: 0, routes: [{ name: "index" }] })
          ),
      ],
      // 带一个变化的 query 参数 → react-navigation 认为是**新路由** → 走 push
      ["push带参", () => router.push({ pathname: "/", params: { t: String(Date.now()) } })],
      ["push中转页", () => router.push("/home-from-settings")],
    ];
    for (const [name, fn] of attempts) {
      try {
        fn();
        try {
          ToastAndroid.show(`返回:${name}`, ToastAndroid.SHORT);
        } catch {}
        return;
      } catch (e: any) {
        try {
          ToastAndroid.show(`失败:${name}`, ToastAndroid.SHORT);
        } catch {}
      }
    }
    goBackSafely(router);
  }, [router, navigation]);

  useFocusEffect(
    React.useCallback(() => {
      if (Platform.OS !== "android") return;
      const onBack = () => {
        goBack();
        return true;
      };
      const sub = BackHandler.addEventListener("hardwareBackPress", onBack);
      return () => sub.remove();
    }, [goBack])
  );

  // 动态样式
  const dynamicStyles = createResponsiveStyles(deviceType, spacing, insets);

  const renderSettingsContent = () => (
    // <KeyboardAvoidingView style={{ flex: 1, backgroundColor }} behavior={Platform.OS === "ios" ? "padding" : "height"}>
    <KeyboardAwareScrollView
      enableOnAndroid={true}
      extraScrollHeight={20}
      keyboardOpeningTime={0}
      keyboardShouldPersistTaps="always"
      scrollEnabled={true}
      style={{ flex: 1, backgroundColor }}
    >

      <ThemedView style={[commonStyles.container, dynamicStyles.container]}>
        {deviceType === "tv" && (
          <View style={dynamicStyles.header}>
            {/* ★ 可见的返回按钮 ——
                TV 上「按返回键」用户不一定知道，一个能点的返回更直观；
                它同时也是焦点系统里的第一个可聚焦控件，进入页面时焦点会落在它身上。 */}
            {/* ★ style 必须写成**函数**形式！
                RN TV 的 Pressable 里：
                  const shouldUpdatePressed =
                    typeof children === 'function' || typeof style === 'function';
                只有 shouldUpdatePressed 为 true 时，内部 `focused` state 才会被
                焦点事件更新。而 onPress 的触发条件是 `focused && eventType === 'select'`。
                style 传对象 → shouldUpdatePressed=false → focused 永远是 false
                → **按 OK 永远不触发 onPress**（按钮看得见、点不动）。
                用函数式 style 后焦点框和 onPress 都正常。 */}
            <Pressable
              style={({ focused }) => [
                dynamicStyles.backButton,
                focused && dynamicStyles.backButtonFocused,
              ]}
              focusable
              onPress={goBack}
            >
              <ThemedText style={dynamicStyles.backButtonText}>‹ 返回</ThemedText>
            </Pressable>
            <ThemedText style={dynamicStyles.title}>设置</ThemedText>
            {/* 路由自检：设置页能打开就说明 expo-router 正常。
                顺便把当前 pathname 显示出来，方便一眼确认。 */}
            <ThemedText style={{ color: "#888", fontSize: 12, marginTop: 4 }}>
              {`route: ${usePathname()}`}
            </ThemedText>
          </View>
        )}

        {/* <View style={dynamicStyles.scrollView}>
          <FlatList
            data={sections}
            renderItem={({ item }) => {
              if (item) {
                return item.component;
              }
              return null;
            }}
            keyExtractor={(item) => (item ? item.key : "default")}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={dynamicStyles.listContent}
          />
        </View> */}
        <View style={dynamicStyles.scrollView}>
          {sections.map(item => (
            // 必须把 key 放在最外层的 View 上
            <View key={item.key} style={dynamicStyles.itemWrapper}>
              {item.component}
            </View>
          ))}
        </View>

        <View style={dynamicStyles.footer}>
          <Pressable
            ref={saveButtonRef}
            focusable
            onFocus={() => {
              setCurrentSection("save");
              focusIndexRef.current = focusOrder.indexOf("settings.save");
            }}
            onPress={handleSaveAndExit}
            style={[isLoading && { opacity: 0.5 }]}
          >
            <StyledButton
              text={isLoading ? "保存中..." : "保存并退出"}
              variant="primary"
              style={dynamicStyles.saveButton}
            />
          </Pressable>
        </View>
      </ThemedView>
    </KeyboardAwareScrollView>
    // </KeyboardAvoidingView>
  );

  // 根据设备类型决定是否包装在响应式导航中
  if (deviceType === "tv") {
    return (
      <SettingsFocusContext.Provider value={focusRegistry.value}>
        {renderSettingsContent()}
      </SettingsFocusContext.Provider>
    );
  }

  return (
    <SettingsFocusContext.Provider value={focusRegistry.value}>
      <ResponsiveNavigation>
        <ResponsiveHeader title="设置" showBackButton />
        {renderSettingsContent()}
      </ResponsiveNavigation>
    </SettingsFocusContext.Provider>
  );
}

const createResponsiveStyles = (deviceType: string, spacing: number, insets: any) => {
  const isMobile = deviceType === "mobile";
  const isTablet = deviceType === "tablet";
  const isTV = deviceType === "tv";
  const minTouchTarget = DeviceUtils.getMinTouchTargetSize();

  return StyleSheet.create({
    backButtonFocused: {
      borderColor: Colors.dark.primary,
      backgroundColor: "#FA8C1618",
    },
    backButton: {
      alignSelf: "flex-start",
      paddingVertical: 6,
      paddingHorizontal: 14,
      marginBottom: 8,
      borderRadius: 8,
      borderWidth: 2.5,
      borderColor: Colors.dark.primary,
      backgroundColor: "#FA8C1618",
    },
    backButtonText: {
      color: Colors.dark.primary,
      fontSize: 18,
      fontWeight: "bold",
    },
    container: {
      flex: 1,
      padding: spacing,
      paddingTop: isTV ? spacing * 2 : isMobile ? insets.top + spacing : insets.top + spacing * 1.5,
    },
    header: {
      flexDirection: "row",
      justifyContent: "space-between",
      alignItems: "center",
      marginBottom: spacing,
    },
    title: {
      fontSize: isMobile ? 24 : isTablet ? 28 : 32,
      fontWeight: "bold",
      paddingTop: spacing,
      color: "white",
    },
    scrollView: {
      flex: 1,
    },
    listContent: {
      paddingBottom: spacing,
    },
    footer: {
      paddingTop: spacing,
      alignItems: isMobile ? "center" : "flex-end",
    },
    saveButton: {
      minHeight: isMobile ? minTouchTarget : isTablet ? 50 : 50,
      width: isMobile ? "100%" : isTablet ? 140 : 120,
      maxWidth: isMobile ? 280 : undefined,
    },
    disabledButton: {
      opacity: 0.5,
    },
    itemWrapper: {
      marginBottom: spacing,   // 这里的 spacing 来自 useResponsiveLayout()
    },
  });
};
