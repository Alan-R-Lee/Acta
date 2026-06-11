# AI Proxy

轻量的后端代理示例，用于将第三方 AI 服务请求保存在服务器端并避免在客户端暴露 API Key。

快速开始：

1. 复制 `.env.example` 为 `.env`，填入你的密钥与 endpoint。
2. 安装依赖并启动：

```bash
cd server/ai-proxy
npm install
npm start
```

接口：
- `POST /v1/generate`
  - body: `{ prompt: string, provider?: 'huawei'|'deepseek' }`
  - 返回: `{ result: string }

安全提示：生产环境请使用 HTTPS、鉴权和速率限制，并将密钥存储在安全的密钥管理服务中。
