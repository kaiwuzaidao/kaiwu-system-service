name: kaiwu-${projectCode}-web

services:
  kaiwu-${projectCode}-web:
    build:
      context: ../..
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "127.0.0.1:${r"${BUSINESS_WEB_PORT:-"}${localWebPort}}:8080"
