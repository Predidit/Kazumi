# 部署指南

## Docker 部署

### 方式 1: 使用 Docker Compose (推荐本地测试)

```bash
# 进入项目目录
cd ios-liquid-glass-video-player

# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 方式 2: 直接使用 Docker

```bash
# 构建镜像
docker build -t anime-player .

# 运行容器
docker run -d \
  --name anime-player \
  -p 3000:3000 \
  --shm-size=2g \
  --security-opt seccomp=unconfined \
  anime-player

# 查看日志
docker logs -f anime-player
```

### 方式 3: 部署到 Zeabur

1. 在 Zeabur 创建新项目
2. 选择 "Deploy from GitHub" 或 "Deploy from Docker Image"
3. 如果使用 GitHub:
   - 连接你的 GitHub 仓库
   - Zeabur 会自动检测 Dockerfile 并构建
4. 如果使用 Docker Image:
   - 先推送镜像到 Docker Hub:
     ```bash
     docker build -t your-username/anime-player .
     docker push your-username/anime-player
     ```
   - 在 Zeabur 中输入镜像名称

#### Zeabur 环境变量配置

在 Zeabur 控制台设置以下环境变量:

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `NODE_ENV` | `production` | 生产环境 |
| `PUPPETEER_EXECUTABLE_PATH` | `/usr/bin/chromium` | Chromium 路径 |

#### Zeabur 资源配置建议

- **内存**: 至少 1GB，推荐 2GB (Chromium 需要)
- **CPU**: 至少 0.5 核，推荐 1 核
- **共享内存**: 如果可配置，设置为 2GB

---

## 常见问题

### Q: Puppeteer 启动失败

确保容器有足够的共享内存:
```bash
docker run --shm-size=2g ...
```

或在 docker-compose.yml 中设置:
```yaml
shm_size: '2gb'
```

### Q: 视频解析超时

视频解析需要 10-20 秒，确保:
1. 服务器有足够的 CPU 和内存
2. 网络连接稳定
3. 没有防火墙阻止出站连接

### Q: 字体显示问题

Docker 镜像已包含中文字体 (fonts-noto-cjk)，如果仍有问题:
```bash
apt-get install fonts-wqy-zenhei fonts-noto-cjk
```

### Q: 内存不足

Chromium 需要较多内存，建议:
- 最小: 1GB
- 推荐: 2GB
- 如果同时处理多个请求: 4GB

---

## 端口说明

| 端口 | 用途 |
|------|------|
| 3000 | HTTP 服务 |

---

## API 端点

| 端点 | 说明 |
|------|------|
| `/` | 首页 |
| `/api/bangumi/*` | Bangumi API 代理 |
| `/api/dandanplay/*` | 弹弹Play API 代理 |
| `/api/plugins/*` | 插件 API |
| `/api/proxy/video` | 视频代理 |
| `/api/proxy/image` | 图片代理 |

---

## 健康检查

```bash
curl http://localhost:3000/api/bangumi/calendar
```

返回 200 表示服务正常。
