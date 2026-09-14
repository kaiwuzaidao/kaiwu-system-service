import { getIntl, getLocale } from '@umijs/max';
import { currentAccessToken, whenAccessTokenSettled } from '@/utils/accessToken';
import { readProjectId } from '@/hooks/useProjectId';

export interface ApiEnvelope<T> {
  code: number;
  message?: string;
  /** 稳定错误标识，前端据此翻译；服务端未返回时回退 message。 */
  messageKey?: string;
  messageArgs?: Record<string, unknown>;
  data: T;
}

export type JsonRequestInit = RequestInit & { projectId?: string };

let sessionNoticeShown = false;

/**
 * 401 的处置：只提示，不自动跳转。
 *
 * 令牌只存在于内存，且只能经同源 postMessage 向主站窗口索取（见 utils/accessToken）——
 * 这要求本页有 opener 或 parent，只有平台用 window.open 打开子应用时才成立。
 * 独立打开的顶层页面（书签、粘贴 URL、整页跳转）永远拿不到令牌。
 *
 * 曾经尝试过自动跳转，两次都出了问题：
 *
 * - 跳 /login?redirect=<自身> —— 登录后跳回来仍是无令牌的顶层页面，立刻又 401，
 *   在登录页与子应用之间无限弹跳。
 * - 跳平台首页 —— 判断"是否还有希望拿到令牌"依赖 window.opener 是否存活，
 *   这个信号会误判（主站标签页被关掉、被导航走都会让它失效），一旦判错就把人
 *   从正常使用中弹出应用，比停在原地更糟。
 *
 * 所以改为不动页面，只覆盖一层提示，把去向交给用户。用户不会被弹走、不会进入
 * 弹跳，也不会像最初那样对着空白表格不知道发生了什么。
 */
function showSessionNotice(): void {
  if (typeof document === 'undefined' || sessionNoticeShown) return;
  sessionNoticeShown = true;

  const mask = document.createElement('div');
  mask.setAttribute('role', 'alertdialog');
  mask.setAttribute('aria-label', '会话已失效');
  mask.style.cssText = [
    'position:fixed',
    'inset:0',
    'z-index:2147483647',
    'background:rgba(15,20,19,.45)',
    'display:flex',
    'align-items:center',
    'justify-content:center',
    'font-family:-apple-system,"PingFang SC",sans-serif',
  ].join(';');

  const card = document.createElement('div');
  card.style.cssText = [
    'background:#fff',
    'color:#14191a',
    'border-radius:8px',
    'padding:24px 28px',
    'max-width:380px',
    'width:calc(100% - 48px)',
    'box-shadow:0 8px 32px rgba(0,0,0,.18)',
    'line-height:1.6',
  ].join(';');

  const title = document.createElement('div');
  title.textContent = '会话已失效';
  title.style.cssText = 'font-size:16px;font-weight:600;margin-bottom:8px';

  const body = document.createElement('div');
  body.textContent =
    '请回到 Kaiwu 平台，从项目入口重新进入本应用。直接打开本页地址无法获取登录状态。';
  body.style.cssText = 'font-size:13.5px;color:#4d5957;margin-bottom:18px';

  const link = document.createElement('a');
  link.href = '/';
  link.textContent = '前往 Kaiwu 平台';
  link.style.cssText = [
    'display:inline-block',
    'background:#4f46e5',
    'color:#fff',
    'padding:7px 16px',
    'border-radius:6px',
    'text-decoration:none',
    'font-size:13.5px',
  ].join(';');

  card.append(title, body, link);
  mask.append(card);
  document.body.append(mask);
}

export async function requestJson<T>(path: string, init: JsonRequestInit = {}): Promise<T> {
  const { projectId = readProjectId(), headers: initialHeaders, ...fetchInit } = init;
  // 令牌是异步经 postMessage 从主站送达的，首屏请求必须等它落定，
  // 否则会先发一发无令牌请求、拿到 401，再被当成会话失效。
  await whenAccessTokenSettled();
  const headers = new Headers(initialHeaders);
  headers.set('Content-Type', 'application/json');
  const token = currentAccessToken();
  if (token) headers.set('Authorization', `Bearer ${r"${token}"}`);
  if (projectId) headers.set('X-Project-Id', projectId);
  // 服务端据此下发对应语言的字典标签与错误消息。
  if (!headers.has('Accept-Language')) headers.set('Accept-Language', getLocale());

  const response = await fetch(path, { ...fetchInit, headers });
  let payload: ApiEnvelope<T> | undefined;
  try {
    payload = (await response.json()) as ApiEnvelope<T>;
  } catch {
    // Gateway 或反向代理可能返回 HTML；统一转换为可读错误。
  }
  if (response.status === 401) {
    showSessionNotice();
  }
  if (!response.ok || !payload) {
    // 优先用稳定 key 翻译成当前界面语言；语言包缺 key 或旧服务端未返回 key 时，
    // 回退服务端消息——宁可显示服务端语言，也不显示 key 本身或空白。
    const translated = payload?.messageKey
      ? getIntl().formatMessage(
          { id: payload.messageKey, defaultMessage: payload.message ?? payload.messageKey },
          // formatMessage 只接受原始值，而契约上 messageArgs 本就只放可安全展示的值，
          // 这里统一转成字符串：插值只用于展示，不参与任何逻辑判断。
          payload.messageArgs
            ? Object.fromEntries(
                Object.entries(payload.messageArgs).map(([key, value]) => [key, String(value)]),
              )
            : undefined,
        )
      : undefined;
    throw new Error(
      translated ||
        payload?.message ||
        getIntl().formatMessage(
          {
            id: [502, 503, 504].includes(response.status)
              ? 'common.error.unavailable'
              : 'common.error.request',
          },
          { status: response.status },
        ),
    );
  }
  if (payload.code !== 0) {
    throw new Error(payload.message || `请求失败（code ${r"${payload.code}"}）`);
  }
  return payload.data;
}
