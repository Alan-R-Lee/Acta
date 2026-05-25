export class TravelNote {
  id: string;
  routeId: string;
  title: string;
  content: string;
  images: string[];
  createdAt: number;

  constructor(id: string, routeId: string, title: string, content: string) {
    this.id = id;
    this.routeId = routeId;
    this.title = title;
    this.content = content;
    this.images = [];
    this.createdAt = Date.now();
  }
}