#!/bin/bash

DEPLOY_DIR="/www/wwwroot/lyra"
LOG_FILE="/www/wwwroot/lyra/deploy.log"

echo "========================================" >> "$LOG_FILE"
echo "Deploy started at $(date)" >> "$LOG_FILE"

cd "$DEPLOY_DIR" || exit 1

git pull origin main >> "$LOG_FILE" 2>&1

pnpm install --frozen-lockfile >> "$LOG_FILE" 2>&1

pnpm build >> "$LOG_FILE" 2>&1

pm2 restart lyra >> "$LOG_FILE" 2>&1

echo "Deploy finished at $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
