# Lyra 部署与 CI/CD 操作指南

> 目标：将 Lyra Studio（基于 vercel/chatbot 二开）部署到腾讯云宝塔服务器，并实现 Cursor push 后自动更新。

## 前置条件

| 项目 | 状态 |
|------|------|
| GitHub 仓库 | `tangchangzhe/chatbot`（已 Fork） |
| 服务器 | 腾讯云 2C4G，宝塔面板 11.6.0 |
| 域名 | `lyra.zerupta.com`（站点已创建） |
| Node.js + PM2 | 已通过宝塔 PM2 管理器安装 |
| PostgreSQL | 已安装，数据库 `lyra` / 用户 `lyra` 已创建 |
| 本地开发 | `d:\dev\personal\Lyra\lyra-studio\`（已 Clone） |

---

## 第一步：服务器上克隆项目

SSH 登录服务器，执行：

```bash
# 进入站点目录，清理原有 PHP 文件
cd /www/wwwroot/lyra
rm -rf *
rm -rf .[!.]* 2>/dev/null

# 克隆你的 Fork 仓库
git clone https://github.com/tangchangzhe/chatbot.git .
```

> 注意末尾的 `.`，表示克隆到当前目录而非创建子目录。

---

## 第二步：创建环境变量文件

```bash
cat > /www/wwwroot/lyra/.env.local << 'EOF'
# ===== 认证 =====
AUTH_SECRET=<用 openssl rand -base64 32 生成，或复用 ai.zerupta.com 的>
AUTH_TRUST_HOST=true

# ===== AI =====
AI_GATEWAY_API_KEY=<复用 ai.zerupta.com 的 .env.local 中的值>

# ===== 数据库 =====
POSTGRES_URL=postgresql://lyra:<你的密码>@localhost:5432/lyra

# ===== 文件存储（暂留空） =====
BLOB_READ_WRITE_TOKEN=

# ===== Redis（可选） =====
REDIS_URL=

# ===== 端口 =====
PORT=3100
EOF
```

---

## 第三步：安装依赖并构建

```bash
cd /www/wwwroot/lyra
pnpm install
pnpm build
```

`pnpm build` 会自动执行两件事：
1. 数据库迁移（`tsx lib/db/migrate`）—— 自动创建所有表
2. Next.js 生产构建

> 如果 `pnpm` 命令不存在，先执行：`npm install -g pnpm`

---

## 第四步：在宝塔添加 Node 项目

打开宝塔面板，按以下步骤操作（和你部署 `ai.zerupta.com` 时一样）：

1. 进入 **Node 项目**（或 PM2 管理器）
2. 点击 **添加项目**，填写：

| 配置项 | 值 |
|--------|-----|
| 项目名称 | `lyra` |
| 项目目录 | `/www/wwwroot/lyra` |
| 启动命令 | `pnpm start` 或 `npm start` |
| 端口 | `3100` |

3. 启动项目
4. 将域名 `lyra.zerupta.com` 映射到该 Node 项目（和 `ai.zerupta.com` 操作一致）

**验证**：浏览器访问 `https://lyra.zerupta.com`，能看到 chatbot 界面即成功。

---

## 第五步：配置 Webhook 自动部署

### 5.1 给部署脚本加执行权限

```bash
chmod +x /www/wwwroot/lyra/scripts/deploy.sh
```

部署脚本 `scripts/deploy.sh` 已在仓库中，内容为：

```bash
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
```

### 5.2 宝塔面板安装 Webhook 插件

1. 宝塔面板 → **软件商店**
2. 搜索 **"宝塔WebHook"** → 安装
3. 打开插件 → 点击 **添加**：
   - **名称**：`lyra-deploy`
   - **脚本内容**：
     ```bash
     #!/bin/bash
     bash /www/wwwroot/lyra/scripts/deploy.sh
     ```
4. 添加完成后，点击 **查看密钥**
5. 你会看到 Webhook URL，格式类似：
   ```
   http://面板IP:8888/hook?access_key=xxxxxxxxxx
   ```
6. **复制这个 URL**（后面要用）

### 5.3 GitHub 仓库添加 Webhook

1. 打开 https://github.com/tangchangzhe/chatbot/settings/hooks
2. 点击 **Add webhook**
3. 填写：

| 配置项 | 值 |
|--------|-----|
| Payload URL | 宝塔给的 Webhook URL |
| Content type | `application/json` |
| Secret | 留空 |
| Which events | 选 **Just the push event** |

4. 点击 **Add webhook**

---

## 第六步：验证 CI/CD 闭环

回到本地 Cursor 编辑器：

1. 随便改一处 UI 文字（比如打开 `components/chat/greeting.tsx`，修改欢迎文案）
2. 提交并推送：
   ```bash
   git add .
   git commit -m "test: verify CI/CD pipeline"
   git push origin main
   ```
3. 等待 30-60 秒（服务器需要 `pnpm build`）
4. 刷新 `https://lyra.zerupta.com`，确认改动已生效

---

## 常用运维命令

```bash
# 查看 PM2 进程状态
pm2 status

# 查看应用日志
pm2 logs lyra

# 手动重启应用
pm2 restart lyra

# 查看部署日志
tail -50 /www/wwwroot/lyra/deploy.log
```

---

## 目录结构概览

```
/www/wwwroot/lyra/              # 服务器项目根目录
├── .env.local                  # 环境变量（不入 Git）
├── .next/                      # Next.js 构建产物
├── scripts/
│   └── deploy.sh               # Webhook 触发的部署脚本
├── app/                        # Next.js App Router
├── components/                 # React 组件
├── lib/                        # 工具库、数据库、AI
├── deploy.log                  # 部署日志
└── ...
```

---

## 故障排查

| 问题 | 排查方式 |
|------|----------|
| 网站无法访问 | `pm2 status` 检查进程是否运行 |
| 502 Bad Gateway | 检查端口是否匹配（Nginx 反代端口 vs 应用端口） |
| 数据库连接失败 | 检查 `.env.local` 中 `POSTGRES_URL` |
| Webhook 没触发 | 查看 GitHub Webhook 的 Recent Deliveries |
| 构建失败 | `tail -100 /www/wwwroot/lyra/deploy.log` |
