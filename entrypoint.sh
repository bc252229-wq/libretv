#!/bin/sh
set -e
node /app/danmu/danmu_api/server.js &
exec node /app/server.js