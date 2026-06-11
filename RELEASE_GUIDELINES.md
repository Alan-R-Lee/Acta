# Release & Open-source Guidelines

1. 配置与凭证
- 不要在仓库中提交任何密钥或凭证。使用环境变量或平台密钥管理服务（如 GitHub Secrets、云 KMS）。
- 提供 `.env.example` 作为示例并在 `.gitignore` 中忽略 `.env`。

2. CI 与 质量检查
- 在引入 AI 或第三方服务时，确保 CI 中包含静态分析、单元测试与至少一个集成测试（使用模拟或代理）。

3. 许可证
- 在公开仓库中选择合适的许可证（MIT/Apache-2.0 等），并添加 `LICENSE` 文件。

4. 服务器部署
- 为后端代理使用 HTTPS、认证与速率限制。生产中请避免直接从客户端调用第三方 AI API。
