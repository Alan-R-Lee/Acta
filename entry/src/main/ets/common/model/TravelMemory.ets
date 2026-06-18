export class TravelMemory {
  id: string;
  routeId: string;
  pointTime: number;
  lat: number;
  lng: number;
  altitude: number;
  title: string;
  content: string;
  images: string[];
  createdAt: number;

  constructor(
    id: string,
    routeId: string,
    pointTime: number,
    lat: number,
    lng: number,
    altitude: number,
    title: string,
    content: string
  ) {
    this.id = id;
    this.routeId = routeId;
    this.pointTime = pointTime;
    this.lat = lat;
    this.lng = lng;
    this.altitude = altitude;
    this.title = title;
    this.content = content;
    this.images = [];
    this.createdAt = Date.now();
  }
}
