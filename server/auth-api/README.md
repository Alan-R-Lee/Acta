# Acta Auth API

这是 Acta 的开发版登录/注册服务器。它提供注册、登录、读取当前用户接口；开发阶段用本地 JSON 文件保存用户资料，用 Node 内置 `crypto.pbkdf2` 保存加盐后的密码哈希，不保存明文密码。

## 本地启动

先确认本机安装了 Node.js，然后执行：

```bash
cd server/auth-api
cp .env.example .env
npm install
npm start
```

默认服务地址：

```text
http://127.0.0.1:3100
```

健康检查：

```bash
curl http://127.0.0.1:3100/health
```

## 客户端配置

HarmonyOS 客户端服务器地址在：

```text
entry/src/main/ets/common/service/AuthService.ets
```

修改文件顶部的 `AUTH_CONFIG`：

```ts
const AUTH_CONFIG: AuthConfig = {
  mode: 'server',
  baseUrl: 'http://127.0.0.1:3100',
  fallbackToLocal: true
};
```

`fallbackToLocal: true` 表示服务器连不上时临时回退到本地账号模式，方便开发调试。

真机运行时要注意：手机上的 `127.0.0.1` 指手机自己，不是你的电脑。你需要把 `baseUrl` 改成电脑局域网 IP 或线上服务器域名，例如：

```ts
const AUTH_CONFIG: AuthConfig = {
  mode: 'server',
  baseUrl: 'http://192.168.1.20:3100',
  fallbackToLocal: true
};
```

如果部署到线上并配置了 HTTPS：

```ts
const AUTH_CONFIG: AuthConfig = {
  mode: 'server',
  baseUrl: 'https://api.example.com',
  fallbackToLocal: false
};
```

## 环境变量

复制 `.env.example` 为 `.env` 后可以调整：

```text
PORT=3100
AUTH_DATA_FILE=./data/auth-store.json
TOKEN_TTL_HOURS=168
CORS_ORIGIN=*
```

含义：

```text
PORT             服务监听端口
AUTH_DATA_FILE   用户和登录 token 的本地 JSON 存储文件
TOKEN_TTL_HOURS  登录 token 有效期，默认 168 小时
CORS_ORIGIN      允许跨域的来源，开发期可用 *，生产环境应改成你的域名
```

`data/`、`.env`、`node_modules/` 已在本目录 `.gitignore` 中忽略，不会提交用户数据和本地密钥。

## API

### 注册

```http
POST /api/auth/register
Content-Type: application/json

{
  "username": "demo_user",
  "password": "Passw0rd123",
  "email": "demo@example.com",
  "displayName": "Demo"
}
```

### 登录

```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "demo_user",
  "password": "Passw0rd123"
}
```

### 当前用户

```http
GET /api/users/me
Authorization: Bearer <token>
```

注册和登录都会返回：

```json
{
  "token": "...",
  "user": {
    "id": 1,
    "username": "demo_user",
    "email": "demo@example.com",
    "displayName": "Demo",
    "createdAt": 1710000000000
  }
}
```

## 上线建议

这个版本适合先把客户端和服务器流程跑通。正式上线前建议做这些升级：

```text
1. 把 JSON 文件存储替换成数据库，例如 PostgreSQL、MySQL 或 MongoDB。
2. 使用 HTTPS，避免 token 和账号信息明文传输。
3. 把 CORS_ORIGIN 从 * 改为你的正式域名。
4. 用 pm2、Docker、云函数或云容器托管服务进程。
5. 增加找回密码、修改资料、退出登录、token 刷新和风控限流。
```
