import { RoutePoint } from '../model/RoutePoint';

type PointCallback = (point: RoutePoint) => void;

export class MockLocationService {
  private timerId: number = -1;
  private seedLat: number = 39.908823;
  private seedLng: number = 116.397470;
  private step: number = 0;
  private callback: PointCallback | undefined = undefined;

  start(cb: PointCallback): void {
    this.stop();
    this.callback = cb;

    const id: number = setInterval((): void => {
      this.step += 1;

      const point: RoutePoint = new RoutePoint(
        this.seedLat + this.step * 0.00018,
        this.seedLng + Math.sin(this.step / 2) * 0.00035,
        40 + this.step,
        Date.now(),
        ''
      );

      if (this.callback) {
        this.callback(point);
      }
    }, 1500);

    this.timerId = id;
  }

  stop(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }
}