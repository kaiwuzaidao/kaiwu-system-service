import { useEffect, useSyncExternalStore } from 'react';

const ACCESS_REQUEST = 'KAIWU_ACCESS_REQUEST';
const ACCESS_RESPONSE = 'KAIWU_ACCESS_RESPONSE';
const accessTokenListeners = new Set<() => void>();
let accessTokenVersion = 0;
let accessToken = readBootstrapAccessToken();

/** 桥接握手最长等待时间；超时后按"拿不到令牌"处理，不再无限等。 */
const BRIDGE_TIMEOUT_MS = 5000;

/**
 * 令牌是否已尘埃落定。
 *
 * 主站用 window.open 打开子应用时，令牌是异步经 postMessage 送达的，
 * 而页面首帧的数据请求会在同一轮 effect 里立刻发出——早于令牌到达。
 * 没有这个状态位，首屏必然先打一发无令牌请求、必然 401。
 *
 * pending：本页有 opener/parent，正在等握手回包。
 * settled：已拿到令牌，或已确定拿不到（无宿主窗口、或握手超时）。
 */
let accessTokenSettled = !!accessToken || !hasHostWindow();
let releaseSettled: (() => void) | undefined;
const settledPromise = accessTokenSettled
  ? Promise.resolve()
  : new Promise<void>((resolve) => {
      releaseSettled = resolve;
    });

function hasHostWindow(): boolean {
  if (typeof window === 'undefined') return false;
  return (!!window.opener && !window.opener.closed) || window.parent !== window;
}

function markAccessTokenSettled(): void {
  if (accessTokenSettled) return;
  accessTokenSettled = true;
  releaseSettled?.();
}

/** 请求发出前在此等待：pending 时挂起，settled 后立即通过。 */
export function whenAccessTokenSettled(): Promise<void> {
  return settledPromise;
}

/** 令牌只保存在当前 JavaScript 运行时内存中。 */
export function configureAccessToken(token: string | null | undefined): void {
  const nextToken = token?.trim() ?? '';
  if (nextToken) markAccessTokenSettled();
  if (nextToken === accessToken) return;
  accessToken = nextToken;
  accessTokenVersion += 1;
  accessTokenListeners.forEach((listener) => listener());
}

export function currentAccessToken(): string {
  return accessToken;
}

function readBootstrapAccessToken(): string {
  if (typeof window === 'undefined') return '';
  const bootstrapWindow = window as Window & { __KAIWU_ACCESS_TOKEN__?: unknown };
  const token =
    typeof bootstrapWindow.__KAIWU_ACCESS_TOKEN__ === 'string'
      ? bootstrapWindow.__KAIWU_ACCESS_TOKEN__.trim()
      : '';
  delete bootstrapWindow.__KAIWU_ACCESS_TOKEN__;
  return token;
}

function subscribeAccessToken(onChange: () => void): () => void {
  accessTokenListeners.add(onChange);
  return () => accessTokenListeners.delete(onChange);
}

export function useAccessTokenVersion(): number {
  return useSyncExternalStore(
    subscribeAccessToken,
    () => accessTokenVersion,
    () => 0,
  );
}

/** 从同源 Kaiwu 主站获取一次性内存令牌。 */
export function useHostAccessBridge(): void {
  useEffect(() => {
    if (typeof window === 'undefined') return undefined;
    const hosts = new Set<Window>();
    if (window.opener && !window.opener.closed) hosts.add(window.opener);
    if (window.parent !== window) hosts.add(window.parent);
    if (hosts.size === 0) {
      markAccessTokenSettled();
      return undefined;
    }

    const nonce = window.crypto.randomUUID();
    const receive = (event: MessageEvent<unknown>): void => {
      if (event.origin !== window.location.origin || !hosts.has(event.source as Window)) return;
      const data = event.data;
      if (
        !data ||
        typeof data !== 'object' ||
        (data as { type?: unknown }).type !== ACCESS_RESPONSE ||
        (data as { nonce?: unknown }).nonce !== nonce
      )
        return;
      const token = (data as { accessToken?: unknown }).accessToken;
      if (typeof token === 'string' && token.length <= 16_384) {
        configureAccessToken(token);
      }
    };

    window.addEventListener('message', receive);
    hosts.forEach((host) => {
      host.postMessage({ type: ACCESS_REQUEST, nonce }, window.location.origin);
    });
    // 主站没装桥接、或版本不匹配时不会有回包，超时放行以免整页卡住不发请求。
    const timer = window.setTimeout(markAccessTokenSettled, BRIDGE_TIMEOUT_MS);
    return () => {
      window.clearTimeout(timer);
      window.removeEventListener('message', receive);
    };
  }, []);
}
