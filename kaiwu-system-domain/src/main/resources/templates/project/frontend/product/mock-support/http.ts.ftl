<#noparse>/** Umi 开发中间件提供的 HTTP 对象子集。 */
export interface Request {
  headers: { cookie?: string };
  body?: Record<string, unknown>;
  params: Record<string, string>;
  query: Record<string, unknown>;
}
export interface Response {
  json(data: unknown): Response;
  status(code: number): Response;
  type(contentType: string): Response;
  send(content: string): Response;
  cookie(key: string, value: string, options: Record<string, unknown>): Response;
  clearCookie(key: string, options: Record<string, unknown>): Response;
  redirect(url: string): Response;
  redirect(code: number, url: string): Response;
}
</#noparse>
