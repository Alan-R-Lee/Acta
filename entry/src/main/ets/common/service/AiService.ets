import { TravelRoute } from '../model/TravelRoute';
import { GeoUtil } from '../util/GeoUtil';
import AiClient from './ai/AiClient';

export class AiService {
  static generateRouteInsight(route: TravelRoute): string {
    const distance = GeoUtil.routeDistance(route.points);
    const pointCount = route.points.length;

    if (pointCount === 0) {
      return '当前路线还没有轨迹数据，建议先开始记录或手工绘制路线。';
    }

    let level = '轻量休闲';
    if (distance > 5000) {
      level = '中等强度';
    }
    if (distance > 12000) {
      level = '高强度户外';
    }

    return `AI路书分析：本次路线共采集 ${pointCount} 个轨迹点，估算总里程 ${(distance / 1000).toFixed(2)} km，路线强度为“${level}”。建议准备饮水、补能食品，并在海拔变化明显路段控制节奏。适合作为旅行行记、徒步复盘与分享素材。`;
  }

  // 异步 AI 接口：如果配置了 AI Provider，会通过 AiClient 生成更丰富的分析文本；失败时回退
  static async generateRouteInsightAsync(route: TravelRoute): Promise<string> {
    const distance = GeoUtil.routeDistance(route.points);
    const pointCount = route.points.length;

    if (pointCount === 0) {
      return '当前路线还没有轨迹数据，建议先开始记录或手工绘制路线。';
    }

    const prompt = `请基于以下路由数据生成一段详尽的路线分析建议：点数 ${pointCount}，估算里程 ${(distance / 1000).toFixed(2)} km，包含海拔、节奏建议和分享文案。`;

    try {
      const aiText = await AiClient.generateText(prompt);
      if (aiText && aiText.length > 0) return aiText;
    } catch (e) {
      // 忽略 AI 错误，回退到本地规则
    }

    return this.generateRouteInsight(route);
  }
}