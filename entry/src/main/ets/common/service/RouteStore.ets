import { TravelRoute } from '../model/TravelRoute';
import { TravelNote } from '../model/TravelNote';
import { RoutePoint } from '../model/RoutePoint';
import { TravelMemory } from '../model/TravelMemory';

class RouteStore {
  private routes: TravelRoute[] = [];
  private notes: TravelNote[] = [];
  private memories: TravelMemory[] = [];

  replaceAll(routes: TravelRoute[], notes: TravelNote[], memories: TravelMemory[]): void {
    this.routes = routes;
    this.notes = notes;
    this.memories = memories;
  }

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

  updateRouteTitle(routeId: string, title: string): void {
    const route = this.getRouteById(routeId);
    if (route) {
      route.title = title;
    }
  }

  deleteRoute(routeId: string): void {
    this.routes = this.routes.filter((item: TravelRoute) => item.id !== routeId);
    this.notes = this.notes.filter((item: TravelNote) => item.routeId !== routeId);
    this.memories = this.memories.filter((item: TravelMemory) => item.routeId !== routeId);
  }

  addNote(note: TravelNote): void {
    this.notes.unshift(note);
  }

  getNoteById(id: string): TravelNote | undefined {
    return this.notes.find((item: TravelNote) => item.id === id);
  }

  updateNote(note: TravelNote): void {
    const index = this.notes.findIndex((item: TravelNote) => item.id === note.id);
    if (index >= 0) {
      this.notes[index] = note;
      return;
    }
    this.notes.unshift(note);
  }

  getNotesByRouteId(routeId: string): TravelNote[] {
    return this.notes.filter((item: TravelNote) => item.routeId === routeId);
  }

  addMemory(memory: TravelMemory): void {
    this.memories.unshift(memory);
  }

  getAllNotes(): TravelNote[] {
    return this.notes;
  }

  getAllMemories(): TravelMemory[] {
    return this.memories;
  }

  getMemoriesByRouteId(routeId: string): TravelMemory[] {
    return this.memories.filter((item: TravelMemory) => item.routeId === routeId);
  }

  getMemoriesByPoint(routeId: string, pointTime: number): TravelMemory[] {
    return this.memories.filter((item: TravelMemory) => item.routeId === routeId && item.pointTime === pointTime);
  }
}

export default new RouteStore();
