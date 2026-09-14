name: kaiwu-${projectCode}

services:
  mysql:
    image: mysql:8.4
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: kaiwu_${normalizedProjectCode}
      MYSQL_USER: kaiwu_app
      MYSQL_PASSWORD: ${r"${DB_PASSWORD:?请设置业务库 DB_PASSWORD}"}
      MYSQL_ROOT_PASSWORD: ${r"${DB_ROOT_PASSWORD:?请设置业务库 DB_ROOT_PASSWORD}"}
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -ukaiwu_app -p$$MYSQL_PASSWORD --silent"]
      interval: 5s
      timeout: 5s
      retries: 30

  kaiwu-${projectCode}-service:
    build:
      context: ../..
      dockerfile: Dockerfile
    restart: unless-stopped
    environment:
      DB_HOST: mysql
      DB_PORT: "3306"
      DB_NAME: kaiwu_${normalizedProjectCode}
      DB_USER: kaiwu_app
      DB_PASSWORD: ${r"${DB_PASSWORD:?请设置业务库 DB_PASSWORD}"}
      KAIWU_CONTEXT_PUBLIC_KEY: ${r"${KAIWU_CONTEXT_PUBLIC_KEY:?请设置 KAIWU_CONTEXT_PUBLIC_KEY}"}
      KAIWU_SYSTEM_SERVICE_URI: ${r"${KAIWU_SYSTEM_SERVICE_URI:-http://system-service:8080}"}
    ports:
      - "127.0.0.1:${r"${BUSINESS_SERVER_PORT:-"}${localServerPort}}:8080"
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - default
      - kaiwu-platform

volumes:
  mysql-data:

networks:
  kaiwu-platform:
    external: true
    name: ${r"${KAIWU_PLATFORM_NETWORK:-kaiwu_default}"}
