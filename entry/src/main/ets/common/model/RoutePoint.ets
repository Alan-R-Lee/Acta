export class RoutePoint {
  lat: number;
  lng: number;
  altitude: number;
  time: number;
  note: string;

  constructor(
    lat: number,
    lng: number,
    altitude: number = 0,
    time: number = Date.now(),
    note: string = ''
  ) {
    this.lat = lat;
    this.lng = lng;
    this.altitude = altitude;
    this.time = time;
    this.note = note;
  }
}