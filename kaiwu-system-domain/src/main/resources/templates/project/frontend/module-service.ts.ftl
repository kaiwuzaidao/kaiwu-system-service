import { kaiwuRequest } from '@/kaiwu';

const API_BASE = '/${projectCode}-api/api/${moduleCode}/${resourceCode}';

function toQuery(params: Record<string, unknown>): string {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      search.append(key, String(value));
    }
  });
  return search.toString();
}

export function page${table.entityName}(params: Record<string, unknown>) {
  return kaiwuRequest<{ records: Record<string, unknown>[]; total: number }>(
    `${r"${API_BASE}"}?${r"${toQuery(params)}"}`,
  );
}

export function create${table.entityName}(data: Record<string, unknown>) {
  return kaiwuRequest<void>(API_BASE, {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export function update${table.entityName}(id: string, data: Record<string, unknown>) {
  return kaiwuRequest<void>(`${r"${API_BASE}"}/${r"${id}"}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  });
}

export function delete${table.entityName}(id: string) {
  return kaiwuRequest<void>(`${r"${API_BASE}"}/${r"${id}"}`, {
    method: 'DELETE',
  });
}
