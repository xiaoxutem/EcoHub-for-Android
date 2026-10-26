// Learn more https://docs.expo.io/guides/customizing-metro
const { getDefaultConfig } = require("expo/metro-config");

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

// ★ 只监听项目根。
//
// 原来（从 RN TV 原仓库拷来）写的是 `path.resolve(projectRoot, "../..")` ——
// 那是 monorepo 的写法，会让 Metro 扫描**整个上级工作区**，
// 把同仓库里 Flutter 版的构建产物（build/ 目录 1.6GB，含 libflutter.so）
// 也读进文件索引，打包时直接报：
//
//   RangeError [ERR_FS_FILE_TOO_LARGE]: File size (2265979631) is greater than 2 GiB
//
// 其余配置（nodeModulesPaths / disableHierarchicalLookup / blockList）全部
// 交回 expo 默认值 —— 之前自己覆盖 `resolver.nodeModulesPaths` +
// `disableHierarchicalLookup = true` 时，expo-router 的模块解析会出问题
// （路由表虽然打进 bundle，但运行时导航静默失效）。
config.watchFolders = [__dirname];

module.exports = config;
