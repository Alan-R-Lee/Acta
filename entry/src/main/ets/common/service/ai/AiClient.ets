import HuaweiProvider from './HuaweiProvider';
import DeepSeekProvider from './DeepSeekProvider';
import ServerProxyProvider from './ServerProxyProvider';
import file from '@ohos.file';

type ProviderName = 'huawei' | 'deepseek' | 'server' | 'none';

interface AiConfig {
  provider: ProviderName;
  huawei?: { apiKey: string; endpoint: string };
  deepseek?: { apiKey: string; endpoint: string };
  server?: { endpoint: string };
}

export class AiClient {
  private static config: AiConfig | null = null;

  static async loadConfig(): Promise<void> {
    if (this.config) return;
    try {
      const path = 'entry/mock/ai-config.json5';
      const content = await file.readAsString(path);
      this.config = JSON.parse(content) as AiConfig;
    } catch (e) {
      this.config = { provider: 'none' };
    }
  }

  static async generateText(prompt: string): Promise<string> {
    await this.loadConfig();
    if (!this.config) return '';

    switch (this.config.provider) {
      case 'huawei':
        return HuaweiProvider.generateText(prompt, this.config.huawei!);
      case 'deepseek':
        return DeepSeekProvider.generateText(prompt, this.config.deepseek!);
      case 'server':
        return ServerProxyProvider.generateText(prompt, this.config.server);
      default:
        return `本地AI(离线模拟)：${prompt.slice(0, 120)}`;
    }
  }
}

export default AiClient;
