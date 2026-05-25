import { TravelRoute } from '../model/TravelRoute';
import { GeoUtil } from '../util/GeoUtil';

export class ShareService {
  static buildShareText(route: TravelRoute): string {
    const distance = GeoUtil.routeDistance(route.points);

    return `我在“Acta”完成了一条旅行路线：${route.title}\n` +
      `轨迹点数：${route.points.length}\n` +
      `总里程：${(distance / 1000).toFixed(2)} km\n` +
      `路线摘要：${route.summary || '暂无摘要'}\n` +
      `欢迎查看我的旅行行记！`;
  }
}