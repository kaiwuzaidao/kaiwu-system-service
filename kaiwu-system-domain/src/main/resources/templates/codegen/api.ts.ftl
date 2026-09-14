import { requestJson } from '@/shell';

const API_BASE = '/${projectCode}-api/api/${moduleCode}/${resourceCode}';

function toQuery(params: Record<string, unknown>) {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      search.append(key, String(value));
    }
  });
  return search.toString();
}

export function page${table.entityName}(params: Record<string, unknown>) {
  return requestJson<{ records: Record<string, unknown>[]; total: number }>(
    `${r"${API_BASE}"}?${r"${toQuery(params)}"}`,
    {},
  );
}

export function save${table.entityName}(data: Record<string, unknown>) {
  return requestJson<void>(API_BASE, {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export function delete${table.entityName}(id: string) {
  return requestJson<void>(`${r"${API_BASE}"}/${r"${id}"}`, {
    method: 'DELETE',
  });
}
