# EcoHub for Android

[![Release](https://img.shields.io/github/v/release/fe-spark/EcoHub-for-Android)](https://github.com/fe-spark/EcoHub-for-Android/releases)
[![Download APK](https://img.shields.io/badge/Download-.apk-green?logo=android&logoColor=white)](https://github.com/fe-spark/EcoHub-for-Android/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)

[EcoHub](https://github.com/fe-spark/EcoHub) 的 Android 原生客户端（基于 Flutter 构建）。

> **提示**：本仓库是 EcoHub 的纯客户端应用，**本身不提供、不存储任何影视资源**。安装后需要配置并接入 EcoHub 软件源（服务端）方可正常浏览与观影。
> 
> 相关项目：[EcoHub 主仓库（服务端 + Web）](https://github.com/fe-spark/EcoHub) · [EcoHub for OHOS](https://github.com/fe-spark/EcoHub-for-OHOS)

---

## 📺 Android TV 支持

本分支（`xiaoxutem/EcoHub-for-Android`）在原版基础上增加了 **Android TV 遥控器适配**，
应用会出现在 TV 桌面启动器中，可完全用遥控器操作。

### 遥控器按键映射

| 按键 | 行为 |
| --- | --- |
| 方向键 ↑↓←→ | 在界面元素间移动焦点；播放器内为音量（↑↓）与快进快退（←→） |
| OK / 确认 | 激活当前焦点元素 |
| 播放 / 暂停键 | 播放或暂停视频 |
| 返回键 | 退出全屏 / 返回上一层 |

### TV 端差异

- **左侧竖排导航**：替代手机端的底部导航（1080p 屏下底部导航离观看位置过远）。
- **强制横屏**、字号整体放大 1.25 倍。
- **焦点高亮框**：当前选中项有明显的橙色描边，便于在电视上辨识。

> 所有 TV 特性均由 `TvMode.isTv` 开关控制，**手机 / 平板端行为与原版完全一致**。

### 涉及文件

| 文件 | 作用 |
| --- | --- |
| `lib/utils/tv_mode.dart` | TV 设备探测（`FEATURE_LEANBACK` / `UI_MODE_TYPE_TELEVISION`）与缩放 |
| `lib/components/focus_wrap.dart` | `FocusTap`（可聚焦点击容器）/ `FocusHighlight`（焦点高亮） |
| `lib/components/player/player_dpad_controller.dart` | 播放器 D-pad 控制（进度 / 音量 / 播放暂停） |
| `lib/components/tv_side_nav.dart` | TV 左侧竖排导航 |
| `lib/components/resilient_image.dart` | 封面多地址回退 + 首字占位图 |
| `lib/utils/image_cache_manager.dart` | 全局图片缓存与解码尺寸限制 |

### 性能与体验优化

- **图片缓存**：全局 `CacheManager`（200 张 / 30 天），避免重复下载。
- **按显示尺寸解码**：`memCacheWidth` 限制解码宽度（原图 500~1000px → 按卡片实际宽度解码），
  显著降低内存峰值与解码耗时。
- **重绘隔离**：卡片加 `RepaintBoundary`，列表滚动时不再整页重绘。
- **隐藏页停摆**：非当前 Tab 用 `TickerMode(enabled: false)` 停掉轮播定时器与动画。
- **封面容错**：图床返回 403/404 时按候选地址依次回退，全部失败则显示带首字的占位图，
  不再出现「一片空白」。

### 已知限制：封面图床 403

部分图床（如 `image.jinyingimage.com`）会对特定网络环境返回 **403**
（`openresty` WAF 拦截，返回的是 HTML 错误页而非图片）。

已穷举验证**与客户端无关**：所有路径前缀、所有 Referer（源站/非凡各域名/google）、
桌面与移动 UA、`Sec-Fetch` 头、IPv6、HTTP→HTTPS 301 跳转 —— **全部 403**。
而同一网络下的 `image.tmdb.org`（轮播图、每日更新）**完全正常**。

**结论**：这是**图床/源站侧的防盗链限制，客户端无法绕过**。
客户端已做的应对：

- **图床熔断**（`ImageHostGuard`）：启动时探测图床可达性，不可用则加入熔断名单，
  后续同域名图片**直接走占位图，不发起任何网络请求** ——
  这同时解决了「首页卡顿」（原本 200+ 张卡片各自发起一次注定失败的请求）。
- **首字占位图**（`PosterFallback`）：影片首字 + 由名称哈希决定的稳定色相，
  不同影片颜色可区分，不再是「一片空白」。
- **图片代理配置**（设置 → 图片代理）：若源站或你自己的服务器提供图片代理接口，
  填入前缀即可显示原始封面。例如前缀填 `https://your-site/api/img?url=`，
  客户端会把原始地址 URL-encode 后拼接上去。

> **要彻底解决**：需由源站提供图片代理接口
> （服务端已有 `server/internal/handler/proxy_handler.go` 的代理基础设施可复用）。

---

## 📥 下载安装

- 🚀 **[下载最新版本 APK (Releases Latest)](https://github.com/fe-spark/EcoHub-for-Android/releases/latest)**
  - 现代主流 Android 手机请下载 `*-arm64-v8a.apk`（体积更小）
  - 较老机型请下载 `*-armeabi-v7a.apk`
- 📜 **[查看所有历史版本与更新日志](https://github.com/fe-spark/EcoHub-for-Android/releases)**

---

## 📡 软件源说明

客户端所有影视列表、分类、搜索、播放地址均由 **EcoHub 软件源** 提供。

### 1. 软件源怎么来？

- **自建部署（推荐）**  
  按照 [EcoHub 部署指南](https://github.com/fe-spark/EcoHub/blob/main/docs/README-Deploy.md) 在你的服务器上部署 EcoHub 服务端。  
  部署成功后，在管理后台「工作台」点击「订阅地址」即可获取客户端订阅源：
  ```
  http://<你的服务器IP或域名>:3000/api/provide/app
  ```
  *(若配置了 HTTPS 或反向代理，格式为 `https://<你的域名>/api/provide/app`，亦兼容原 `/api` 路径)*。在管理后台完成影视数据采集后，客户端即可直接同步。

- **使用公共源 / 他人分享源**  
  如果你有朋友已经部署了 EcoHub 站点，或使用社区公开的 EcoHub 节点，可以直接获取其软件源地址填入（例如官方演示源 `https://eco.fe-spark.cn/api/provide/app`）。

### 2. 如何在 App 中配置？

1. 打开 App，首次进入或未连接时会自动弹出 **软件源配置** 界面；
2. 输入软件源地址（如 `http://<服务器IP或域名>:3000` 或复制后台完整的 `/api/provide/app` 订阅源，未填协议头会自动补齐 `https://`；若站点开启了私有化访问，在地址末尾追加 `?key=您的密钥`）；
3. 点击 **开始观影** / **重新接入**，App 会自动测试与服务端的连通性（请求 `/api/provide/app` 接口）；
4. 校验通过后即可进入首页观影。后续可在「我的」或设置中管理/切换历史软件源。

---

## 推荐

### 服务器

| 服务商 | 说明 | 链接 |
| --- | --- | --- |
| CloudCone | 1. 演示站点所用服务商<br>2. 高性价比 VPS，磁盘 I/O 不受限 | [前往选购](https://app.cloudcone.com/?ref=14393) |

### 网络服务

| 服务商 | 特点 / 价格 | 链接 |
| --- | --- | --- |
| 良心云 | 低至 2 元/月 <br>新用户注册即获体验流量 | [前往注册](https://xn--9kqz23b19z.com/#/register?code=xAmvfdic) |
| 赔钱机场 | 低至 1.5 元/月 <br>适合高流量与备用需求 | [前往注册](https://xn--mes358aby2apfg.com/register?code=FA4xlzHD&cover=sfw) |
| DOVE |  | [前往注册](https://dovee.cc/a.php?asbcbO1PCgTx2JM66) |

---

## 🛠️ 本地开发

确保本地已安装 [Flutter SDK](https://flutter.dev/docs/get-started/install)：

```bash
# 获取依赖
flutter pub get

# 运行调试
flutter run

# 打包 APK（分包构建各架构独立 APK）
flutter build apk --release --split-per-abi
```

---

## 📄 开源许可

本项目遵循 [PolyForm Noncommercial 1.0.0](https://github.com/fe-spark/EcoHub/blob/main/LICENSE) 协议。
