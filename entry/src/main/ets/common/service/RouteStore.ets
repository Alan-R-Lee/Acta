import { TravelRoute } from '../model/TravelRoute';
import { TravelNote } from '../model/TravelNote';
import { RoutePoint } from '../model/RoutePoint';

class RouteStore {
  private routes: TravelRoute[] = [];
  private notes: TravelNote[] = [];

  getRoutes(): TravelRoute[] {
    return this.routes;
  }

  getRouteById(id: string): TravelRoute | undefined {
    return this.routes.find((item: TravelRoute) => item.id === id);
  }

  addRoute(route: TravelRoute): void {
    this.routes.unshift(route);
  }

  appendPoint(routeId: string, point: RoutePoint): void {
    const route = this.getRouteById(routeId);
    if (route) {
      route.points.push(point);
    }
  }

  updateRouteSummary(routeId: string, summary: string): void {
    const route = this.getRouteById(routeId);
    if (route) {
      route.summary = summary;
    }
  }

  addNote(note: TravelNote): void {
    this.notes.unshift(note);
  }

  getNotesByRouteId(routeId: string): TravelNote[] {
    return this.notes.filter((item: TravelNote) => item.routeId === routeId);
  }
}

export default new RouteStore();