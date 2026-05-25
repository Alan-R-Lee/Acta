import { TravelRoute } from '../model/TravelRoute';
import { GeoUtil } from '../util/GeoUtil';

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
}