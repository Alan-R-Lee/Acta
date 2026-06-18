# AI 功能设计与接入说明

目标：在不影响现有业务代码的前提下，逐步引入 AI 能力（文本生成、路线分析、描述补全等）。

目录：
- 概览与选型
- 本地接入流程（客户端）
- 服务端协作与安全性
- 开源与分发考虑

1. 概览与选型
- 可选提供者：Huawei AI、DeepSeek。两者都支持通过 REST API 调用文本/生成模型。
- 初期在客户端提供可插拔的 Provider 封装，必要时将重点能力迁移到服务端以便统一治理与计费。

2. 本地接入流程（客户端）
- 新增 `entry/src/main/ets/common/service/ai/AiClient.ets` 作为统一入口。
- 在 `entry/mock/ai-config.json5` 配置 provider 与凭证（仅用于开发/测试），生产应通过安全方式注入。
- Provider 实现位于 `entry/src/main/ets/common/service/ai/`。

3. 服务端协作与安全性
- 推荐把敏感凭证和模型调用放到后端服务，由后端负责调用第三方 AI API，客户端通过短期令牌或校验后的接口访问后端。
- 后端可做熔断、限流、缓存、审计与成本控制。

4. 开源与分发考虑
- 配置文件不应包含真实密钥。示例配置 `ai-config.json5` 仅作示例。
- 文档中说明如何搭配后端部署与如何替换 provider 实现。

下一步：我可以把 AiClient 与占位 Provider 集成进现有的 `AiService`，并实现一次真实的 Huawei API 调用示例（需要你提供测试密钥或我添加一个后端代理样例）。要我继续吗？
服务器入口：C:\Windows\System32\OpenSSH\ssh.exe -i C:\VMkey\kr1_key.pem azureuser@40.82.145.83