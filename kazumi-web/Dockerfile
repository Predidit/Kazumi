# ============================================
# 番剧播放器 Docker 镜像
# 支持 Puppeteer + Chromium 用于视频解析
# ============================================

# 阶段 1: 依赖安装
FROM node:20-slim AS deps

WORKDIR /app

# 复制 package 文件
COPY package.json package-lock.json* ./

# 安装依赖 (包括 devDependencies 用于构建)
RUN npm ci

# ============================================
# 阶段 2: 构建
FROM node:20-slim AS builder

WORKDIR /app

# 复制依赖
COPY --from=deps /app/node_modules ./node_modules

# 复制源代码
COPY . .

# 设置环境变量
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
# 跳过 Puppeteer 下载 Chromium (我们在 runner 阶段安装)
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# 构建应用
RUN npm run build

# ============================================
# 阶段 3: 生产运行
FROM node:20-slim AS runner

WORKDIR /app

# 设置环境变量 (在安装包之前)
ENV DEBIAN_FRONTEND=noninteractive
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CHROMIUM_PATH=/usr/bin/chromium

# 安装 Chromium 和必要的依赖
RUN apt-get update && apt-get install -y \
    chromium \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-thai-tlwg \
    fonts-kacst \
    fonts-freefont-ttf \
    fonts-noto-cjk \
    libxss1 \
    libxtst6 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 创建非 root 用户
RUN groupadd --gid 1001 nodejs && \
    useradd --uid 1001 --gid nodejs --shell /bin/bash --create-home nextjs

# 设置运行时环境变量
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# 复制构建产物
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# 切换到非 root 用户
USER nextjs

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node -e "const http = require('http'); http.get('http://localhost:3000/api/bangumi/calendar', (r) => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

# 启动命令
CMD ["node", "server.js"]
