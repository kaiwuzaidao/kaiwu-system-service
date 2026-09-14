server {
    listen 8080;
    server_name _;
    root /usr/share/nginx/html;

    location /apps/${projectCode}/ {
        try_files <#noparse>$uri $uri/</#noparse> /apps/${projectCode}/index.html;
    }

    # 独立部署时反代 API 到 Gateway；嵌入主站时由主站 Gateway 路由，不走这里。
    location /${projectCode}-api/ {
        proxy_pass http://kaiwu-kaiwu-gateway:8088;
<#noparse>        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;</#noparse>
    }
}
