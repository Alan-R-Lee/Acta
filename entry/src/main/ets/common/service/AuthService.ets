import http from '@ohos.net.http';
import { PreferenceService } from './PreferenceService';
import { User } from '../model/User';

type AuthMode = 'server' | 'local';
type AuthSource = 'server' | 'local';

interface AuthConfig {
  mode: AuthMode;
  baseUrl: string;
  fallbackToLocal: boolean;
}

interface AuthRequestBody {
  username: string;
  password: string;
  email?: string;
  displayName?: string;
}

interface AuthUserDto {
  id: number;
  username: string;
  email?: string;
  displayName?: string;
  createdAt?: number;
}

interface AuthResponse {
  token?: string;
  user?: AuthUserDto;
  error?: string;
  message?: string;
}

interface UserPlainObject {
  id: number;
  username: string;
  passwordHash: string;
  createdAt: number;
  email?: string;
  displayName?: string;
}

export interface AuthResult {
  success: boolean;
  message: string;
  source: AuthSource;
  user?: User;
  token?: string;
}

const AUTH_CONFIG: AuthConfig = {
  mode: 'server',
  baseUrl: 'http://127.0.0.1:3100',
  fallbackToLocal: true
};

export class AuthService {
  static async register(username: string, password: string, email: string = '', displayName: string = ''): Promise<AuthResult> {
    const config = AUTH_CONFIG;
    if (config.mode === 'server') {
      const serverResult = await AuthService.registerRemote(config, username, password, email, displayName);
      if (serverResult.success || !AuthService.canFallback(serverResult, config)) {
        return serverResult;
      }
    }

    return AuthService.registerLocal(username, password, email, displayName);
  }

  static async login(username: string, password: string): Promise<AuthResult> {
    const config = AUTH_CONFIG;
    if (config.mode === 'server') {
      const serverResult = await AuthService.loginRemote(config, username, password);
      if (serverResult.success || !AuthService.canFallback(serverResult, config)) {
        return serverResult;
      }
    }

    return AuthService.loginLocal(username, password);
  }

  private static async registerRemote(
    config: AuthConfig,
    username: string,
    password: string,
    email: string,
    displayName: string
  ): Promise<AuthResult> {
    const body: AuthRequestBody = {
      username,
      password,
      email,
      displayName
    };
    return AuthService.requestAuth(`${config.baseUrl}/api/auth/register`, body);
  }

  private static async loginRemote(config: AuthConfig, username: string, password: string): Promise<AuthResult> {
    const body: AuthRequestBody = {
      username,
      password
    };
    return AuthService.requestAuth(`${config.baseUrl}/api/auth/login`, body);
  }

  private static async requestAuth(url: string, body: AuthRequestBody): Promise<AuthResult> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 8000,
        readTimeout: 8000
      });
      const responseText = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result);
      const data = JSON.parse(responseText) as AuthResponse;
      const code = response.responseCode;

      if (code < 200 || code >= 300) {
        return {
          success: false,
          message: data.error || data.message || `Server returned ${code}`,
          source: 'server'
        };
      }

      if (!data.user || !data.token) {
        return {
          success: false,
          message: 'Server response is missing user or token.',
          source: 'server'
        };
      }

      const user = AuthService.fromDto(data.user);
      await AuthService.saveSession(user, data.token);
      return {
        success: true,
        message: data.message || 'Auth succeeded.',
        source: 'server',
        user,
        token: data.token
      };
    } catch {
      return {
        success: false,
        message: 'AUTH_SERVER_UNREACHABLE',
        source: 'server'
      };
    } finally {
      request.destroy();
    }
  }

  private static canFallback(result: AuthResult, config: AuthConfig): boolean {
    return config.fallbackToLocal && result.message === 'AUTH_SERVER_UNREACHABLE';
  }

  private static async registerLocal(
    username: string,
    password: string,
    email: string,
    displayName: string
  ): Promise<AuthResult> {
    const users = await AuthService.loadLocalUsers();
    const exists = users.some((item: User) => item.username === username);
    if (exists) {
      return {
        success: false,
        message: 'Username already exists.',
        source: 'local'
      };
    }

    const maxId = users.reduce((value: number, item: User) => Math.max(value, item.id), 0);
    const user = new User(maxId + 1, username, AuthService.simpleHash(password), Date.now(), email, displayName);
    users.unshift(user);
    await PreferenceService.setUsersJson(JSON.stringify(users));
    await AuthService.saveSession(user, '');
    return {
      success: true,
      message: 'Registered in local fallback mode.',
      source: 'local',
      user
    };
  }

  private static async loginLocal(username: string, password: string): Promise<AuthResult> {
    const users = await AuthService.loadLocalUsers();
    const passwordHash = AuthService.simpleHash(password);
    const user = users.find((item: User) => item.username === username && item.passwordHash === passwordHash);
    if (!user) {
      return {
        success: false,
        message: 'Username or password is incorrect.',
        source: 'local'
      };
    }

    await AuthService.saveSession(user, '');
    return {
      success: true,
      message: 'Logged in with local fallback mode.',
      source: 'local',
      user
    };
  }

  private static async loadLocalUsers(): Promise<User[]> {
    const jsonText = await PreferenceService.getUsersJson();
    if (!jsonText || jsonText.trim() === '') {
      return [];
    }

    try {
      const arr = JSON.parse(jsonText) as UserPlainObject[];
      const users: User[] = [];
      for (let i = 0; i < arr.length; i++) {
        const item = arr[i];
        users.push(new User(
          item.id,
          item.username,
          item.passwordHash,
          item.createdAt,
          item.email || '',
          item.displayName || ''
        ));
      }
      return users;
    } catch {
      return [];
    }
  }

  private static async saveSession(user: User, token: string): Promise<void> {
    await PreferenceService.setFirstLaunch(false);
    await PreferenceService.setLoggedIn(true);
    await PreferenceService.setCurrentUserId(user.id);
    await PreferenceService.setCurrentUsername(user.displayName || user.username);
    await PreferenceService.setAuthToken(token);
  }

  private static fromDto(dto: AuthUserDto): User {
    return new User(
      dto.id,
      dto.username,
      '',
      dto.createdAt || Date.now(),
      dto.email || '',
      dto.displayName || ''
    );
  }

  private static simpleHash(text: string): string {
    let hash = 0;
    for (let i = 0; i < text.length; i++) {
      hash = ((hash << 5) - hash) + text.charCodeAt(i);
      hash |= 0;
    }
    return `${hash}`;
  }
}
