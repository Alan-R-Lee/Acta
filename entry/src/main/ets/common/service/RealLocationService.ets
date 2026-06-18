import geoLocationManager from '@ohos.geoLocationManager';
import { BusinessError } from '@ohos.base';
import { RoutePoint } from '../model/RoutePoint';

type PointCallback = (point: RoutePoint) => void;
type ErrorCallback = (message: string) => void;

export class RealLocationService {
  private pollingTimer: number = -1;
  private isFetching: boolean = false;
  private isRunning: boolean = false;

  start(cb: PointCallback, onError?: ErrorCallback): void {
    this.stop();
    this.isRunning = true;

    const request: geoLocationManager.LocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.ACCURACY,
      scenario: geoLocationManager.LocationRequestScenario.TRAJECTORY_TRACKING,
      maxAccuracy: 50
    };

    const fetchLocation = async (): Promise<void> => {
      if (!this.isRunning || this.isFetching) {
        return;
      }

      this.isFetching = true;
      try {
        const location = await geoLocationManager.getCurrentLocation(request);
        if (!this.isRunning) {
          return;
        }

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
      } catch (error) {
        const err = error as BusinessError;
        if (onError) {
          onError(`启动定位失败：${err.message || err.code}`);
        }
      } finally {
        this.isFetching = false;
      }
    };

    void fetchLocation();
    this.pollingTimer = setInterval(() => {
      void fetchLocation();
    }, 500);
  }

  stop(): void {
    this.isRunning = false;
    this.isFetching = false;
    if (this.pollingTimer >= 0) {
      clearInterval(this.pollingTimer);
      this.pollingTimer = -1;
    }
  }
}
