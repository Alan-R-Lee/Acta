import http from '@ohos.net.http';
import { AUTH_CONFIG } from './AuthService';
import { PreferenceService } from './PreferenceService';
import RouteStore from './RouteStore';
import { TravelRoute } from '../model/TravelRoute';
import { TravelNote } from '../model/TravelNote';
import { TravelMemory } from '../model/TravelMemory';
import { RoutePoint } from '../model/RoutePoint';

interface TravelSnapshotDto {
  routes?: TravelRouteDto[];
  notes?: TravelNoteDto[];
  memories?: TravelMemoryDto[];
}

interface TravelRouteDto {
  id: string;
  title: string;
  summary?: string;
  points?: RoutePointDto[];
  tags?: string[];
  createdAt?: number;
  cover?: string;
}

interface TravelNoteDto {
  id: string;
  routeId: string;
  title: string;
  content?: string;
  images?: string[];
  createdAt?: number;
}

interface TravelMemoryDto {
  id: string;
  routeId: string;
  pointTime?: number;
  lat: number;
  lng: number;
  altitude?: number;
  title: string;
  content?: string;
  images?: string[];
  createdAt?: number;
}

interface RoutePointDto {
  lat: number;
  lng: number;
  altitude?: number;
  altitudeAccuracy?: number;
  time?: number;
  note?: string;
}

export class TravelDataService {
  static async syncFromServer(): Promise<boolean> {
    const token = await PreferenceService.getAuthToken();
    if (!token) {
      return false;
    }

    const data = await TravelDataService.request('/api/travel/snapshot', http.RequestMethod.GET, undefined, token) as TravelSnapshotDto | undefined;
    if (!data) {
      return false;
    }

    const routes = Array.isArray(data.routes) ? data.routes.map((item: TravelRouteDto) => TravelDataService.toRoute(item)) : [];
    const notes = Array.isArray(data.notes) ? data.notes.map((item: TravelNoteDto) => TravelDataService.toNote(item)) : [];
    const memories = Array.isArray(data.memories) ? data.memories.map((item: TravelMemoryDto) => TravelDataService.toMemory(item)) : [];
    RouteStore.replaceAll(routes, notes, memories);
    return true;
  }

  static async createRoute(route: TravelRoute): Promise<void> {
    await TravelDataService.request('/api/routes', http.RequestMethod.POST, {
      id: route.id,
      title: route.title,
      summary: route.summary,
      points: route.points,
      tags: route.tags,
      createdAt: route.createdAt,
      cover: route.cover
    });
  }

  static async appendPoint(routeId: string, point: RoutePoint): Promise<void> {
    await TravelDataService.request(`/api/routes/${routeId}/points`, http.RequestMethod.POST, point);
  }

  static async updateRouteSummary(routeId: string, summary: string): Promise<void> {
    await TravelDataService.request(`/api/routes/${routeId}`, http.RequestMethod.PUT, { summary });
  }

  static async createNote(note: TravelNote): Promise<void> {
    await TravelDataService.request(`/api/routes/${note.routeId}/notes`, http.RequestMethod.POST, note);
  }

  static async createMemory(memory: TravelMemory): Promise<void> {
    await TravelDataService.request(`/api/routes/${memory.routeId}/memories`, http.RequestMethod.POST, memory);
  }

  private static async request(path: string, method: http.RequestMethod, body?: Object, tokenOverride?: string): Promise<Object | undefined> {
    if (AUTH_CONFIG.mode !== 'server') {
      return undefined;
    }

    const token = tokenOverride || await PreferenceService.getAuthToken();
    if (!token) {
      return undefined;
    }

    const request = http.createHttp();
    try {
      const response = await request.request(`${AUTH_CONFIG.baseUrl}${path}`, {
        method,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        extraData: body ? JSON.stringify(body) : undefined,
        connectTimeout: 8000,
        readTimeout: 8000
      });

      if (response.responseCode < 200 || response.responseCode >= 300) {
        return undefined;
      }

      const responseText = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result);
      return responseText ? JSON.parse(responseText) as Object : {};
    } catch {
      return undefined;
    } finally {
      request.destroy();
    }
  }

  private static toRoute(dto: TravelRouteDto): TravelRoute {
    const route = new TravelRoute(dto.id, dto.title);
    route.summary = dto.summary || '';
    route.points = Array.isArray(dto.points) ? dto.points.map((point: RoutePointDto) => {
      return new RoutePoint(
        point.lat,
        point.lng,
        point.altitude || 0,
        point.time || Date.now(),
        point.note || '',
        point.altitudeAccuracy
      );
    }) : [];
    route.tags = Array.isArray(dto.tags) ? dto.tags : [];
    route.createdAt = dto.createdAt || Date.now();
    route.cover = dto.cover || '';
    return route;
  }

  private static toNote(dto: TravelNoteDto): TravelNote {
    const note = new TravelNote(dto.id, dto.routeId, dto.title, dto.content || '');
    note.images = Array.isArray(dto.images) ? dto.images : [];
    note.createdAt = dto.createdAt || Date.now();
    return note;
  }

  private static toMemory(dto: TravelMemoryDto): TravelMemory {
    const memory = new TravelMemory(
      dto.id,
      dto.routeId,
      dto.pointTime || Date.now(),
      dto.lat,
      dto.lng,
      dto.altitude || 0,
      dto.title,
      dto.content || ''
    );
    memory.images = Array.isArray(dto.images) ? dto.images : [];
    memory.createdAt = dto.createdAt || Date.now();
    return memory;
  }
}
