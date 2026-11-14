#!/usr/bin/env node
/** 在一次性本地 HTTP 服务中验收真实生成的首页；请求全部使用 fixture，不连接平台环境。 */
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { resolve, extname } from "node:path";

const sample = resolve(
  "kaiwu-system-domain/target/project-scaffold-sample/frontend",
);
const blank = resolve(
  "kaiwu-system-domain/target/basic-scaffold-sample/frontend",
);
const require = createRequire(`${sample}/package.json`);
const { chromium, expect } = require("@playwright/test");
const projectId = "9000000000000001001";
const server = createServer(async (req, res) => {
  const url = new URL(req.url, "http://localhost");
  if (url.pathname === "/__host") {
    const code = url.searchParams.get("code");
    if (!["order-center", "blank-desk"].includes(code)) {
      res.writeHead(400).end();
      return;
    }
    res.setHeader("content-type", "text/html; charset=utf-8");
    res.end(
      `<!doctype html><iframe style="width:100%;height:900px;border:0" src="/apps/${code}/?projectId=${projectId}"></iframe><script>addEventListener('message',e=>{if(e.origin!==location.origin||e.source!==document.querySelector('iframe').contentWindow||e.data?.type!=='KAIWU_ACCESS_REQUEST')return;e.source.postMessage({type:'KAIWU_ACCESS_RESPONSE',nonce:e.data.nonce,accessToken:'fixture-only'},location.origin)})</script>`,
    );
    return;
  }
  const match = url.pathname.match(/^\/apps\/(order-center|blank-desk)\/(.*)$/);
  if (!match) {
    res.writeHead(404).end();
    return;
  }
  const root = match[1] === "order-center" ? sample : blank;
  const file = resolve(root, "dist", match[2] || "index.html");
  if (!file.startsWith(`${root}/dist/`)) {
    res.writeHead(400).end();
    return;
  }
  try {
    const mime = {
      ".js": "text/javascript",
      ".css": "text/css",
      ".html": "text/html; charset=utf-8",
    };
    res.setHeader(
      "content-type",
      mime[extname(file)] || "application/octet-stream",
    );
    res.end(await readFile(file));
  } catch {
    res.writeHead(404).end();
  }
});
await new Promise((done) => server.listen(0, "127.0.0.1", done));
const origin = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({ channel: "chrome", headless: true });
try {
  const page = await browser.newPage();
  page.on("pageerror", (error) =>
    console.error("Fixture page error:", error.message),
  );
  page.on("response", (response) => {
    if (response.status() >= 400)
      console.error(
        "Fixture HTTP:",
        response.status(),
        new URL(response.url()).pathname,
      );
  });
  let denied = false;
  let fail = false;
  await page.route("**/*", async (route) => {
    const url = new URL(route.request().url());
    if (url.origin !== origin) return route.abort();
    if (!url.pathname.startsWith("/api/")) return route.continue();
    if (url.pathname === "/api/current/todos") {
      if (url.searchParams.get("projectCode") !== "order-center")
        throw new Error("Wrong project filter");
      return route.fulfill({
        json: { code: 0, data: { records: [], total: 0 } },
      });
    }
    if (url.pathname.endsWith("/access") && fail)
      return route.fulfill({
        status: 503,
        json: { code: 1, message: "Fixture unavailable" },
      });
    const data = url.pathname.endsWith("/access")
      ? {
          permissions: denied ? [] : ["order:order:list"],
          menus: [
            {
              id: "orders",
              menuName: "订单管理",
              menuType: "MENU",
              routePath: "/order",
              visible: true,
              status: "ACTIVE",
              permissionCode: "order:order:list",
            },
            {
              id: "members",
              menuName: "项目成员",
              menuType: "MENU",
              routePath: "/project-members",
              visible: true,
              status: "ACTIVE",
            },
          ],
          userLocale: "zh-CN",
        }
      : url.pathname === "/api/auth/me"
        ? { id: "fixture", username: "fixture", displayName: "本地模板验收" }
        : [];
    return route.fulfill({ json: { code: 0, data } });
  });
  await page.goto(`${origin}/__host?code=order-center`);
  const app = page.frameLocator("iframe");
  const entry = app.getByRole("link", { name: "进入订单管理", exact: true });
  await expect(entry).toBeVisible();
  await expect(app.locator(".kaiwu-content-frame")).toHaveCSS(
    "padding-left",
    "40px",
  );
  await expect(app.locator(".kaiwu-content-frame")).toHaveCSS(
    "padding-top",
    "32px",
  );
  await expect(
    app.locator(".ant-pro-page-container-children-container"),
  ).toHaveCSS("padding-left", "0px");
  await expect(app.locator(".ant-pro-global-header")).toHaveCSS(
    "height",
    "56px",
  );
  await expect(app.locator(".ant-pro-sider")).toHaveCSS("width", "256px");
  await expect(app.locator(".kaiwu-page-breadcrumb")).toBeVisible();
  await expect(app.locator(".kaiwu-desktop-header")).toHaveCount(0);
  await expect(entry).toHaveAttribute(
    "href",
    `/apps/order-center/order?projectId=${projectId}`,
  );
  await expect(app.locator(".kaiwu-sidebar-footer")).toHaveCount(0);
  await expect(app.locator(".kaiwu-header-account:visible")).toHaveCount(1);
  await expect(
    app.getByRole("menuitem", { name: "项目成员", exact: true }),
  ).toHaveCount(0);
  await expect(
    app.getByRole("menuitem", { name: "待办", exact: true }),
  ).toBeVisible();
  await app.getByRole("menuitem", { name: "待办", exact: true }).click();
  await expect(app.getByText("暂无待办事项")).toBeVisible();
  await page.reload();
  await page.goto(`${origin}/__host?code=order-center`);
  denied = true;
  await page.reload();
  await expect(
    app.getByText("暂无可用业务入口，请联系项目管理员开通权限。"),
  ).toBeVisible();
  await expect(entry).toHaveCount(0);
  fail = true;
  await page.reload();
  await expect(app.getByText("项目权限加载失败，请重试。")).toBeVisible();
  denied = false;
  fail = false;
  await app.getByRole("button", { name: /^重\s*试$/ }).click();
  await expect(entry).toBeVisible();
  await page.goto(`${origin}/__host?code=blank-desk`);
  await expect(
    app.getByText("项目暂未开放业务功能，请联系项目管理员。"),
  ).toBeVisible();
  await expect(app.getByText("基础脚手架已生成", { exact: false })).toHaveCount(
    0,
  );
  console.log(
    "Generated homepage acceptance passed: real module/blank builds, permission denial, retry, project links, single header account.",
  );
} finally {
  await browser.close();
  server.close();
}
