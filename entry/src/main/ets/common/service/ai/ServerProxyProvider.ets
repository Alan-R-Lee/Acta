interface ServerCfg { endpoint: string }

export default class ServerProxyProvider {
  static async generateText(prompt: string, cfg?: ServerCfg): Promise<string> {
    const endpoint = cfg && cfg.endpoint ? cfg.endpoint : 'http://127.0.0.1:3000/v1/generate';
    try {
      // 使用 fetch 发起请求；在部分运行时需替换为平台 HTTP 客户端
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt })
      });
      if (!res.ok) {
        return `服务代理错误：${res.status}`;
      }
      const data = await res.json();
      return data.result || '';
    } catch (e) {
      return `服务代理调用失败：${(e && e.message) || e}`;
    }
  }
}
