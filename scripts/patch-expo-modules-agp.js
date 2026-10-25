/**
 * 修复 expo-modules-core 与新版 Android Gradle Plugin 的兼容问题。
 *
 * ## 问题
 *
 * `ExpoModulesCorePlugin.gradle` 里有一段 `publishing { publications { release { from components.release } } }`。
 * AGP 8.x 起 `components.release` 这个 SoftwareComponent 已被移除
 * （改成 `releaseRuntimeElements` / `releaseApiElements` …），
 * 于是配置阶段直接报：
 *
 *   Could not get unknown property 'release' for SoftwareComponent container
 *
 * ## 处理
 *
 * 这段 publishing 只在「把库发布成 maven 构件」时才有用，
 * 本地 assembleRelease 用不到 —— 直接移除即可。
 *
 * 放在 patch 脚本里而不是直接改 node_modules，是为了 `yarn install` 后能重现。
 */
const fs = require('fs');
const path = require('path');

const target = path.join(
  __dirname,
  '..',
  'node_modules',
  'expo-modules-core',
  'android',
  'ExpoModulesCorePlugin.gradle'
);

if (!fs.existsSync(target)) {
  console.log('[patch-expo-modules-agp] 目标文件不存在，跳过');
  process.exit(0);
}

let content = fs.readFileSync(target, 'utf8');
if (content.includes('[patch-expo-modules-agp]')) {
  console.log('[patch-expo-modules-agp] 已打过补丁，跳过');
  process.exit(0);
}

// 移除 publishing 块（从 "project.afterEvaluate {" 里的 publishing 到对应闭合）
const marker = '  project.afterEvaluate {\n    publishing {';
const idx = content.indexOf(marker);
if (idx < 0) {
  console.log('[patch-expo-modules-agp] 未找到 publishing 块，跳过');
  process.exit(0);
}

// 找到该 afterEvaluate 块的结束（用大括号配平）
let depth = 0;
let end = -1;
for (let i = idx; i < content.length; i++) {
  if (content[i] === '{') depth++;
  else if (content[i] === '}') {
    depth--;
    if (depth === 0) {
      end = i + 1;
      break;
    }
  }
}
if (end < 0) {
  console.log('[patch-expo-modules-agp] 无法定位 publishing 块边界，跳过');
  process.exit(0);
}

content =
  content.slice(0, idx) +
  '  // [patch-expo-modules-agp] 已移除与 AGP 8.x 不兼容的 publishing 块' +
  content.slice(end);

fs.writeFileSync(target, content);
console.log('[patch-expo-modules-agp] 已移除不兼容的 publishing 块');
