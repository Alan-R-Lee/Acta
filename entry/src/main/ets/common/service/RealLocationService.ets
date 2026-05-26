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

    this.locationCallback = (location: geoLocationManager.Location): void => {
      const altitude: number = typeof location.altitude === 'number' ? location.altitude : 0;
      const time: number = typeof location.timeStamp === 'number' && location.timeStamp > 0
        ? location.timeStamp
        : Date.now();

      cb(new RoutePoint(location.latitude, location.longitude, altitude, time, ''));
    };

    try {
      geoLocationManager.on('locationChange', request, this.locationCallback);
    } catch (error) {
      const err = error as BusinessError;
      this.locationCallback = undefined;
      if (onError) {
        onError(`启动定位失败：${err.message || err.code}`);
      }
    }
  }

  stop(): void {
    if (this.locationCallback) {
      geoLocationManager.off('locationChange', this.locationCallback);
      this.locationCallback = undefined;
    }
  }
}
