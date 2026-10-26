import React, { forwardRef } from "react";
import { Animated, Pressable, StyleSheet, StyleProp, ViewStyle, PressableProps, TextStyle, View, Platform } from "react-native";
import { ThemedText } from "./ThemedText";
import { Colors } from "@/constants/Colors";
import { useButtonAnimation } from "@/hooks/useAnimation";
import { useResponsiveLayout } from "@/hooks/useResponsiveLayout";

interface StyledButtonProps extends PressableProps {
  children?: React.ReactNode;
  text?: string;
  variant?: "default" | "primary" | "ghost";
  isSelected?: boolean;
  style?: StyleProp<ViewStyle>;
  textStyle?: StyleProp<TextStyle>;
}

export const StyledButton = forwardRef<View, StyledButtonProps>(
  ({ children, text, variant = "default", isSelected = false, style, textStyle, ...rest }, ref) => {
    const colorScheme = "dark";
    const colors = Colors[colorScheme];
    const [isFocused, setIsFocused] = React.useState(false);
    const animationStyle = useButtonAnimation(isFocused);
    const deviceType = useResponsiveLayout().deviceType;
    /** 是否电视端（TV 上 Pressable 必须 focusable 才能成为原生焦点目标）。 */
    const isTv = Platform.isTV || deviceType === 'tv';

    const variantStyles = {
      default: StyleSheet.create({
        button: {
          backgroundColor: colors.border,
        },
        text: {
          color: colors.text,
        },
        selectedButton: {
          backgroundColor: colors.primary,
        },
        focusedButton: {
          borderColor: colors.focus,
          // 电视上焦点框必须够粗才看得见（1px 基本不可见）
          borderWidth: 2.5,
        },
        selectedText: {
          color: Colors.dark.text,
        },
      }),
      primary: StyleSheet.create({
        button: {
          backgroundColor: "transparent",
        },
        text: {
          color: colors.text,
        },
        focusedButton: {
          backgroundColor: colors.primary,
          borderColor: colors.background,
        },
        selectedButton: {
          backgroundColor: colors.primary,
        },
        selectedText: {
          color: colors.link,
        },
      }),
      ghost: StyleSheet.create({
        button: {
          backgroundColor: "transparent",
        },
        text: {
          color: colors.text,
        },
        focusedButton: {
          backgroundColor: "rgba(119, 119, 119, 0.2)",
          borderColor: colors.focus,
        },
        selectedButton: {},
        selectedText: {},
      }),
    };

    const styles = StyleSheet.create({
      button: {
        paddingHorizontal: 16,
        paddingVertical: 10,
        borderRadius: 8,
        borderWidth: 2,
        borderColor: "transparent",
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
      },
      focusedButton: {
        backgroundColor: colors.link,
        borderColor: colors.background,
        elevation: 5,
        shadowColor: colors.link,
        shadowOffset: { width: 0, height: 0 },
        shadowOpacity: 1,
        shadowRadius: 15,
      },
      selectedButton: {
        backgroundColor: colors.tint,
      },
      text: {
        fontSize: 16,
        fontWeight: "500",
        color: colors.text,
      },
      selectedText: {
        color: Colors.dark.text,
      },
    });

    return (
      <Animated.View style={[animationStyle, style]}>
        <Pressable
          android_ripple={Platform.isTV || deviceType !== 'tv'? { color: 'transparent' } : { color: Colors.dark.link }}
          // ★ 电视上必须显式 focusable（放在 {...rest} 之后，见下方注释）
          //
          // React Native TV 的 `Pressable` 默认 `focusable={false}` ——
          // 不改的话它**不会成为原生焦点目标**，焦点会落在外层容器（FlatList / ScrollView）上，
          // 方向键被容器消费去滚动，焦点永远出不去：
          // 表现为「焦点框卡在某个 chip 上，↑↓→ 全部没反应」，
          // 连带右上角的设置齿轮也点不到。
          ref={ref}
          // ★ 外部传的 onFocus/onBlur 要**合并**进来，不能被覆盖 ——
          //   否则调用方（比如首页齿轮）无法知道「焦点现在在不在我身上」，
          //   也就无法在页面级 TV 事件里判断「按 OK 是不是要点我」。
          onFocus={(e) => {
            setIsFocused(true);
            (rest as any).onFocus?.(e);
          }}
          onBlur={(e) => {
            setIsFocused(false);
            (rest as any).onBlur?.(e);
  }}
          style={({ focused }) => [
            styles.button,
            variantStyles[variant].button,
            isSelected && (variantStyles[variant].selectedButton ?? styles.selectedButton),
            focused && (variantStyles[variant].focusedButton ?? styles.focusedButton),
          ]}
          {...rest}
          // ★ 必须放在 {...rest} **之后** ——
          // 否则 rest 里没有 focusable 键时（值为 undefined）会把上面的
          // `focusable={true}` 覆盖成 undefined，控件就又不是焦点目标了。
          focusable={isTv ? true : (rest.focusable ?? false)}
        >
          {text ? (
            <ThemedText
              style={[
                styles.text,
                variantStyles[variant].text,
                isSelected && (variantStyles[variant].selectedText ?? styles.selectedText),
                textStyle,
              ]}
            >
              {text}
            </ThemedText>
          ) : (
            children
          )}
        </Pressable>
      </Animated.View>
    );
  }
);

StyledButton.displayName = "StyledButton";
