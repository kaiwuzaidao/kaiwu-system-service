name: kaiwu-${normalizedProjectCode}-local

services:
  mysql:
    image: mysql:8.4
    restart: unless-stopped
    ports:
      - "${r"${DB_PORT:-"}${localDbPort}}:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${r"${KAIWU_LOCAL_DB_ROOT_PASSWORD:?请设置 KAIWU_LOCAL_DB_ROOT_PASSWORD}"}
      MYSQL_DATABASE: ${r"${DB_NAME:-kaiwu_"}${normalizedProjectCode}}
      MYSQL_USER: ${r"${DB_USER:-kaiwu_app}"}
      MYSQL_PASSWORD: ${r"${DB_PASSWORD:?请设置 DB_PASSWORD}"}
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -u$$MYSQL_USER -p$$MYSQL_PASSWORD --silent"]
      interval: 3s
      timeout: 3s
      retries: 30
    volumes:
      - mysql-data:/var/lib/mysql

volumes:
  mysql-data:
