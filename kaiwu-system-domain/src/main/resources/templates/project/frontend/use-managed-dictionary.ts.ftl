import { useCallback, useSyncExternalStore } from 'react';
import { getLocale } from '@umijs/max';
import useProjectId from '@/hooks/useProjectId';
import { requestJson } from '@/services/request';

const DICTIONARY_REFRESH_MS = 5 * 60 * 1000;
const DICTIONARY_RETRY_MS = 5 * 1000;
const EMPTY_OPTIONS: readonly DictOption[] = Object.freeze([]);

export interface DictOption {
  value: string;
  label: string;
  color?: string;
  sortNo?: number;
}

interface ApiItem {
  itemValue?: unknown;
  itemLabel?: unknown;
  color?: unknown;
  sortNo?: unknown;
  status?: unknown;
}

type Payload = ApiItem[] | { items?: ApiItem[]; records?: ApiItem[] };

interface Entry {
  projectId: string;
  dictCode: string;
  locale: string;
  state: 'idle' | 'loading' | 'loaded';
  options: readonly DictOption[];
  listeners: Set<() => void>;
  timer?: ReturnType<typeof setTimeout>;
}

const cache = new Map<string, Entry>();

// 缓存按语言分桶：服务端按 Accept-Language 返回对应语言的标签，
// 只用 [projectId, dictCode] 做键会在切换语言后继续用旧语言的快照。
function entry(projectId: string, dictCode: string, locale: string): Entry {
  const key = JSON.stringify([projectId, dictCode, locale]);
  const existing = cache.get(key);
  if (existing) return existing;
  const created: Entry = {
    projectId,
    dictCode,
    locale,
    state: 'idle',
    options: EMPTY_OPTIONS,
    listeners: new Set(),
  };
  cache.set(key, created);
  return created;
}

function normalize(payload: Payload): readonly DictOption[] {
  const items = Array.isArray(payload) ? payload : (payload.items ?? payload.records ?? []);
  return items
    .filter((item) => item.status === 'ENABLED')
    .map((item) => ({
      value: String(item.itemValue ?? ''),
      label: String(item.itemLabel ?? item.itemValue ?? ''),
      color: typeof item.color === 'string' && item.color ? item.color : undefined,
      sortNo: Number.isFinite(Number(item.sortNo)) ? Number(item.sortNo) : Number.MAX_SAFE_INTEGER,
    }))
    .sort((left, right) => (left.sortNo ?? 0) - (right.sortNo ?? 0));
}

function schedule(value: Entry, delay: number): void {
  if (value.timer) clearTimeout(value.timer);
  value.timer = setTimeout(() => {
    value.timer = undefined;
    value.state = 'idle';
    if (value.listeners.size > 0) load(value);
  }, delay);
}

function load(value: Entry): void {
  if (value.state !== 'idle' || !value.projectId || !value.dictCode) return;
  value.state = 'loading';
  void requestJson<Payload>(
    `/api/current/projects/${r"${encodeURIComponent(value.projectId)}"}/dicts/${r"${encodeURIComponent(value.dictCode)}"}`,
    { projectId: value.projectId },
  )
    .then((payload) => {
      value.options = normalize(payload);
      value.state = 'loaded';
      schedule(value, DICTIONARY_REFRESH_MS);
    })
    .catch(() => {
      value.options = EMPTY_OPTIONS;
      value.state = 'idle';
      schedule(value, DICTIONARY_RETRY_MS);
    })
    .finally(() => value.listeners.forEach((listener) => listener()));
}

export default function useManagedDictionary(dictCode: string): readonly DictOption[] {
  const projectId = useProjectId();
  // 语言变化要重新取数：字典标签由服务端按语言下发。
  const locale = getLocale();
  const subscribe = useCallback(
    (listener: () => void) => {
      if (!projectId || !dictCode) return () => undefined;
      const value = entry(projectId, dictCode, locale);
      value.listeners.add(listener);
      load(value);
      return () => value.listeners.delete(listener);
    },
    [projectId, dictCode, locale],
  );
  const snapshot = useCallback(
    () => (!projectId || !dictCode ? EMPTY_OPTIONS : entry(projectId, dictCode, locale).options),
    [projectId, dictCode, locale],
  );
  return useSyncExternalStore(subscribe, snapshot, () => EMPTY_OPTIONS);
}
