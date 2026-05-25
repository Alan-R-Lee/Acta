import { RoutePoint } from '../model/RoutePoint';

export class GeoUtil {
  private static toRad(d: number): number {
    return d * Math.PI / 180;
  }

  static distance(p1: RoutePoint, p2: RoutePoint): number {
    const R = 6371000;
    const dLat = GeoUtil.toRad(p2.lat - p1.lat);
    const dLng = GeoUtil.toRad(p2.lng - p1.lng);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(GeoUtil.toRad(p1.lat)) *
        Math.cos(GeoUtil.toRad(p2.lat)) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  static routeDistance(points: RoutePoint[]): number {
    if (points.length < 2) {
      return 0;
    }

    let total = 0;
    for (let i = 1; i < points.length; i++) {
      total += GeoUtil.distance(points[i - 1], points[i]);
    }
    return total;
  }
}