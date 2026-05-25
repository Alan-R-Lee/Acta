import { RoutePoint } from './RoutePoint';

export class TravelRoute {
  id: string;
  title: string;
  summary: string;
  points: RoutePoint[];
  tags: string[];
  createdAt: number;
  cover: string;

  constructor(id: string, title: string) {
    this.id = id;
    this.title = title;
    this.summary = '';
    this.points = [];
    this.tags = [];
    this.createdAt = Date.now();
    this.cover = '';
  }
}