// Learn more https://docs.expo.io/guides/customizing-metro
const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

// Find the project and workspace directories
// eslint-disable-next-line no-undef
const projectRoot = __dirname;

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(projectRoot);

// When enabled, the optional code below will allow Metro to resolve
// and bundle source files with TV-specific extensions
// (e.g., *.ios.tv.tsx, *.android.tv.tsx, *.tv.tsx)
//
// Metro will still resolve source files with standard extensions
// as usual if TV-specific files are not found for a module.
//
// if (process.env?.EXPO_TV === '1') {
//   const originalSourceExts = config.resolver.sourceExts;
//   const tvSourceExts = [
//     ...originalSourceExts.map((e) => `tv.${e}`),
//     ...originalSourceExts,
//   ];
//   config.resolver.sourceExts = tvSourceExts;
// }

// ★ 本项目**不是** monorepo —— 仓库根就是项目根。
//
// 原来的 `watchFolders = [path.resolve(projectRoot, "../..")]` 会让 Metro
// 扫描**整个上级工作区**，把同仓库里 Flutter 版的构建产物
// （build/ 目录 1.6GB，含 libflutter.so 等大文件）也读进文件索引，
// 于是打包时报：
//
//   RangeError [ERR_FS_FILE_TOO_LARGE]: File size (2265979631) is greater than 2 GiB
//
// 改成只监听项目根，并用 blockList 排除 Flutter 版目录。
config.watchFolders = [projectRoot];

// 2. 让 Metro 知道去哪找包
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
];
config.resolver.disableHierarchicalLookup = true;

// 3. 排除 Flutter 版（同一仓库里并存的两个实现，不参与 RN 打包）
config.resolver.blockList = [
  /\/flutter\/.*/,
  /\/\.git\/.*/,
  /\/android\/build\/.*/,
];

module.exports = config;
