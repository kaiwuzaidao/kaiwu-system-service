# 加到 Kaiwu 平台域名对应的 server {} 中，保持业务前端与平台同源。
location /apps/${projectCode}/ {
    # 若启动 Compose 时覆盖了 BUSINESS_WEB_PORT，这里同步修改。
    proxy_pass http://127.0.0.1:${localWebPort};
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# API 只能进入 Gateway；不要把本段改成直连业务后端。
location /${projectCode}-api/ {
    proxy_pass http://127.0.0.1:8088;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
}
