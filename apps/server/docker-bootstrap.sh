
#!/bin/sh
# ENVIRONEMTN from docker-compose.yaml doesn't get through to subprocesses
# Need to explicit pass DATABASE_URL here, otherwise migration doesn't work

# 根据 DATABASE_TYPE 选择正确的 Prisma schema
if [ "$DATABASE_TYPE" = "postgresql" ]; then
  echo "使用 PostgreSQL 数据库"
  if [ -d "./prisma-postgresql" ]; then
    echo "切换到 PostgreSQL schema"
    rm -rf ./prisma
    cp -r ./prisma-postgresql ./prisma
  fi
elif [ "$DATABASE_TYPE" = "sqlite" ]; then
  echo "使用 SQLite 数据库"
  if [ -d "./prisma-sqlite" ]; then
    echo "切换到 SQLite schema"
    rm -rf ./prisma
    cp -r ./prisma-sqlite ./prisma
  fi
else
  echo "使用 MySQL 数据库（默认）"
fi

# 生成 Prisma Client
echo "生成 Prisma Client..."
npx prisma generate

# Run migrations
echo "运行数据库迁移..."
DATABASE_URL=${DATABASE_URL} npx prisma migrate deploy

# start app
echo "启动应用..."
DATABASE_URL=${DATABASE_URL} node dist/main