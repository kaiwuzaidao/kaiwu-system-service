import { useCallback, useSyncExternalStore } from 'react';
import useProjectId from '@/hooks/useProjectId';
import { requestJson } from '@/services/request';

const CONFIG_REFRESH_MS = 5 * 60 * 1000;
const CONFIG_RETRY_MS = 5 * 1000;
const EMPTY_CONFIGS: Readonly<Record<string, ProjectConfig>> = Object.freeze({});

export type ProjectConfigValueType = 'STRING' | 'NUMBER' | 'BOOLEAN' | 'JSON';

export interface ProjectConfig {
  key: string;
  value: string;
  valueType: ProjectConfigValueType;
  description?: string;
}

interface ApiConfig {
  key?: unknown;
  value?: unknown;
  valueType?: unknown;
  description?: unknown;
}

type Payload = ApiConfig[] | { items?: ApiConfig[]; records?: ApiConfig[] };

interface Entry {
  projectId: string;
  state: 'idle' | 'loading' | 'loaded';
  configs: Readonly<Record<string, ProjectConfig>>;
  listeners: Set<() => void>;
  timer?: ReturnType<typeof setTimeout>;
}

// 配置一次取回整个项目的生效值，因此按 projectId 缓存即可，不像字典要按 code 分桶。
const cache = new Map<string, Entry>();

function entry(projectId: string): Entry {
  const existing = cache.get(projectId);
  if (existing) return existing;
  const created: Entry = {
    projectId,
    state: 'idle',
    configs: EMPTY_CONFIGS,
    listeners: new Set(),
  };
  cache.set(projectId, created);
  return created;
}

function normalize(payload: Payload): Readonly<Record<string, ProjectConfig>> {
  const items = Array.isArray(payload) ? payload : (payload.items ?? payload.records ?? []);
  const result: Record<string, ProjectConfig> = {};
  for (const item of items) {
    const key = String(item.key ?? '');
    if (!key) continue;
    const valueType = String(item.valueType ?? 'STRING').toUpperCase();
    result[key] = {
      key,
      value: String(item.value ?? ''),
      valueType: (['STRING', 'NUMBER', 'BOOLEAN', 'JSON'].includes(valueType)
        ? valueType
        : 'STRING') as ProjectConfigValueType,
      description:
        typeof item.description === 'string' && item.description ? item.description : undefined,
    };
  }
  return Object.freeze(result);
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
  if (value.state !== 'idle' || !value.projectId) return;
  value.state = 'loading';
  void requestJson<Payload>(
    `/api/current/projects/${r"${encodeURIComponent(value.projectId)}"}/configs`,
    { projectId: value.projectId },
  )
    .then((payload) => {
      value.configs = normalize(payload);
      value.state = 'loaded';
      schedule(value, CONFIG_REFRESH_MS);
    })
    .catch(() => {
      // 平台不可用时退回空集合，由调用方的默认值兜底，页面不因取配置失败而崩。
      value.configs = EMPTY_CONFIGS;
      value.state = 'idle';
      schedule(value, CONFIG_RETRY_MS);
    })
    .finally(() => value.listeners.forEach((listener) => listener()));
}

/** 读取本项目全部生效配置，键为配置 key。平台不可用或未加载完成时返回空对象。 */
export function useProjectConfigs(): Readonly<Record<string, ProjectConfig>> {
  const projectId = useProjectId();
  const subscribe = useCallback(
    (listener: () => void) => {
      if (!projectId) return () => undefined;
      const value = entry(projectId);
      value.listeners.add(listener);
      load(value);
      return () => value.listeners.delete(listener);
    },
    [projectId],
  );
  const snapshot = useCallback(
    () => (!projectId ? EMPTY_CONFIGS : entry(projectId).configs),
    [projectId],
  );
  return useSyncExternalStore(subscribe, snapshot, () => EMPTY_CONFIGS);
}

/**
 * 读取单个配置的字符串值。
 *
 * <p>配置是运行期可改的受管值，不能当作常量缓存到模块作用域；同时必须给 fallback，
 * 平台不可达或该项未配置时才有确定行为。</p>
 */
export default function useProjectConfig(key: string, fallback = ''): string {
  return useProjectConfigs()[key]?.value ?? fallback;
}

/** 按 NUMBER 语义读取；值缺失或不是有效数字时返回 fallback。 */
export function useProjectConfigNumber(key: string, fallback: number): number {
  const raw = useProjectConfigs()[key]?.value;
  const parsed = Number(raw);
  return raw !== undefined && raw !== '' && Number.isFinite(parsed) ? parsed : fallback;
}

/** 按 BOOLEAN 语义读取；只有字符串 "true"（忽略大小写）视为真。 */
export function useProjectConfigBoolean(key: string, fallback = false): boolean {
  const raw = useProjectConfigs()[key]?.value;
  if (raw === undefined || raw === '') return fallback;
  return raw.trim().toLowerCase() === 'true';
}
