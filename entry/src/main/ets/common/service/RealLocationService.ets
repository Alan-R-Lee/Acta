import geoLocationManager from '@ohos.geoLocationManager';
import { BusinessError } from '@ohos.base';
import { RoutePoint } from '../model/RoutePoint';

type PointCallback = (point: RoutePoint) => void;
type ErrorCallback = (message: string) => void;

export class RealLocationService {
  private locationCallback: ((location: geoLocationManager.Location) => void) | undefined = undefined;

  start(cb: PointCallback, onError?: ErrorCallback): void {
    this.stop();

    const request: geoLocationManager.LocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.ACCURACY,
      scenario: geoLocationManager.LocationRequestScenario.TRAJECTORY_TRACKING,
      timeInterval: 1,
      distanceInterval: 3,
      maxAccuracy: 50
    };

    const localCallback = (location: geoLocationManager.Location): void => {
      const altitudeAccuracy: number | undefined = typeof location.altitudeAccuracy === 'number'
        ? location.altitudeAccuracy
        : undefined;
      const altitude: number = typeof location.altitude === 'number' && Number.isFinite(location.altitude)
        ? location.altitude
        : 0;
      const time: number = typeof location.timeStamp === 'number' && location.timeStamp > 0
        ? location.timeStamp
        : Date.now();

      cb(new RoutePoint(location.latitude, location.longitude, altitude, time, '', altitudeAccuracy));
    };

    try {
      // 先用本地回调订阅，订阅成功后再保存到实例字段，避免在订阅失败时保留引用
      geoLocationManager.on('locationChange', request, localCallback);
      this.locationCallback = localCallback;
    } catch (error) {
      const err = error as BusinessError;
      // 订阅失败时不保留引用
      this.locationCallback = undefined;
      if (onError) {
        onError(`启动定位失败：${err.message || err.code}`);
      }
    }
  }

  stop(): void {
    if (!this.locationCallback) {
      return;
    }

    try {
      geoLocationManager.off('locationChange', this.locationCallback);
    } catch (error) {
      const err = error as BusinessError;
      // 如果需要，调用方可传入错误处理；当前接口不带 onError，因此仅静默处理或可扩展日志
      // console.warn && console.warn(`停止定位失败：${err.message || err.code}`);
    } finally {
      // 无论是否成功，都清理引用以防止残留回调
      this.locationCallback = undefined;
    }
  }
}
