name: kaiwu-${projectCode}-web

services:
  kaiwu-${projectCode}-web:
    build:
      context: ../..
      dockerfile: Dockerfile
    healthcheck:
      test: ["CMD", "wget", "-q", "-T", "3", "-O", "/dev/null", "http://127.0.0.1:8080/apps/${projectCode}/index.html"]
      interval: 5s
      timeout: 4s
      start_period: 20s
      retries: 12
    restart: unless-stopped
    ports:
      - "127.0.0.1:${r"${BUSINESS_WEB_PORT:-"}${localWebPort}}:8080"
