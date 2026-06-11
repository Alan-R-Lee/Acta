import http from '@ohos.net.http';

interface AiProxyResponse {
  result?: string;
  error?: string;
}

interface AiPromptBody {
  prompt: string;
}

export default class ServerProxyProvider {
  static async generateText(prompt: string, endpoint: string): Promise<string> {
    const requestEndpoint = endpoint || 'http://127.0.0.1:3000/v1/generate';
    const request = http.createHttp();
    const body: AiPromptBody = { prompt };

    try {
      const response = await request.request(requestEndpoint, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 8000,
        readTimeout: 8000
      });
      const responseText = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result);
      const data = JSON.parse(responseText) as AiProxyResponse;

      if (response.responseCode < 200 || response.responseCode >= 300) {
        return data.error || `服务代理错误：${response.responseCode}`;
      }

      return data.result || '';
    } catch {
      return '服务代理调用失败。';
    } finally {
      request.destroy();
    }
  }
}
