import AsyncStorage from "@react-native-async-storage/async-storage";

const AUTH_TOKEN_KEY = "mytv_auth_token";
const SERVER_FLAGS_KEY = "mytv_server_flags";

export interface ServerFlags {
  privateAccess: boolean;
  requireWebLogin: boolean;
}

// 同步镜像：URL 构造（海报/播放地址追加 token）需要同步取 token
let cachedToken: string | null = null;

/**
 * 读 token。
 *
 * ★ 为什么要加超时：
 *   `panghuFetch` 每次请求前都要 `await getAuthToken()`，
 *   而它读的是 AsyncStorage（原生 SQLite）。
 *   实测在这台电视（VIDAA / Android 6）上这一步会**长时间不返回**，
 *   导致首页一直停在「正在验证服务器配置...」，整个 App 不可用。
 *   （AbortController 的超时信号是在 fetch 之后才挂上的，
 *     根本管不到前面这段 await。）
 *
 *   ⇒ 这里给读取本身加超时，并且优先用内存缓存。
 */
export async function getAuthToken(): Promise<string | null> {
  // 内存缓存命中就不碰原生存储（最快，也最不容易卡）
  if (cachedToken) {
    return cachedToken;
  }
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const t = await Promise.race([
      AsyncStorage.getItem(AUTH_TOKEN_KEY),
      new Promise<null>((resolve) => {
        timer = setTimeout(() => resolve(null), 3000);
      }),
    ]);
    cachedToken = t ?? null;
    return cachedToken;
  } catch {
    // 读失败（原生存储异常）也不能拖死整个请求
    return null;
  } finally {
    if (timer) clearTimeout(timer);
  }
}

export function getCachedAuthToken(): string | null {
  return cachedToken;
}

export async function setAuthToken(token: string): Promise<void> {
  cachedToken = token;
  await AsyncStorage.setItem(AUTH_TOKEN_KEY, token);
}

export async function clearAuthToken(): Promise<void> {
  cachedToken = null;
  await AsyncStorage.removeItem(AUTH_TOKEN_KEY);
}

export async function getServerFlags(): Promise<ServerFlags> {
  const raw = await AsyncStorage.getItem(SERVER_FLAGS_KEY);
  if (!raw) {
    return { privateAccess: false, requireWebLogin: false };
  }
  try {
    const parsed = JSON.parse(raw);
    return {
      privateAccess: !!parsed.privateAccess,
      requireWebLogin: !!parsed.requireWebLogin,
    };
  } catch {
    return { privateAccess: false, requireWebLogin: false };
  }
}

export async function setServerFlags(flags: ServerFlags): Promise<void> {
  await AsyncStorage.setItem(SERVER_FLAGS_KEY, JSON.stringify(flags));
}

export async function clearServerFlags(): Promise<void> {
  await AsyncStorage.removeItem(SERVER_FLAGS_KEY);
}
