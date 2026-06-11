import HuaweiProvider from './HuaweiProvider';
import DeepSeekProvider from './DeepSeekProvider';
import ServerProxyProvider from './ServerProxyProvider';

type ProviderName = 'huawei' | 'deepseek' | 'server' | 'none';

interface HuaweiConfig {
  apiKey: string;
  endpoint: string;
}

interface DeepSeekConfig {
  apiKey: string;
  endpoint: string;
}

interface ServerConfig {
  endpoint: string;
}

interface AiConfig {
  provider: ProviderName;
  huawei: HuaweiConfig;
  deepseek: DeepSeekConfig;
  server: ServerConfig;
}

const AI_CONFIG: AiConfig = {
  provider: 'none',
  huawei: {
    apiKey: '',
    endpoint: 'https://your-huawei-endpoint.example.com/v1/generate'
  },
  deepseek: {
    apiKey: '',
    endpoint: 'https://api.deepseek.example.com/v1/text'
  },
  server: {
    endpoint: 'http://127.0.0.1:3000/v1/generate'
  }
};

export class AiClient {
  static async generateText(prompt: string): Promise<string> {
    switch (AI_CONFIG.provider) {
      case 'huawei':
        return HuaweiProvider.generateText(prompt, AI_CONFIG.huawei.apiKey, AI_CONFIG.huawei.endpoint);
      case 'deepseek':
        return DeepSeekProvider.generateText(prompt, AI_CONFIG.deepseek.apiKey, AI_CONFIG.deepseek.endpoint);
      case 'server':
        return ServerProxyProvider.generateText(prompt, AI_CONFIG.server.endpoint);
      default:
        return `本地AI(离线模拟)：${prompt.slice(0, 120)}`;
    }
  }
}

export default AiClient;
