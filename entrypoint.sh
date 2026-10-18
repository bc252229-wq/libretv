#!/bin/sh
set -e
# 覆盖 Render 环境里的 DANMU_LIMIT（0.8），让 danmu_api 返回最多 2000 条
export DANMU_LIMIT=2
node /app/danmu/danmu_api/server.js &
exec node /app/server.js