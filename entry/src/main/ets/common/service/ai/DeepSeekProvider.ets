interface DeepSeekCfg { apiKey: string; endpoint: string }

export default class DeepSeekProvider {
  static async generateText(prompt: string, cfg: DeepSeekCfg): Promise<string> {
    // DeepSeek 同样为占位实现，按需替换为真实 HTTP 客户端调用
    return `DeepSeek 模型响应（模拟）：基于提示“${prompt.slice(0, 60)}...”生成的文本。`;
  }
}
