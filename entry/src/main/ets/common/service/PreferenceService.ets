import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

const PREF_NAME: string = 'acta_pref';

const KEY_IS_FIRST_LAUNCH: string = 'is_first_launch';
const KEY_IS_LOGGED_IN: string = 'is_logged_in';
const KEY_CURRENT_USER_ID: string = 'current_user_id';
const KEY_CURRENT_USERNAME: string = 'current_username';
const KEY_CURRENT_AVATAR: string = 'current_avatar';
const KEY_USERS_JSON: string = 'users_json';
const KEY_AUTH_TOKEN: string = 'auth_token';
const KEY_NOTE_DRAFT_PREFIX: string = 'note_draft_';

let gPref: preferences.Preferences | null = null;

export class PreferenceService {
  static async init(context: common.UIAbilityContext): Promise<void> {
    if (gPref !== null) {
      return;
    }

    try {
      gPref = await preferences.getPreferences(context, PREF_NAME);
    } catch (error) {
      console.error('PreferenceService init failed.');
    }
  }

  static async ensureDefaults(): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      const firstLaunch = await pref.get(KEY_IS_FIRST_LAUNCH, null);
      if (firstLaunch === null) {
        await pref.put(KEY_IS_FIRST_LAUNCH, true);
        await pref.put(KEY_IS_LOGGED_IN, false);
        await pref.put(KEY_CURRENT_USER_ID, -1);
        await pref.put(KEY_CURRENT_USERNAME, '');
        await pref.put(KEY_CURRENT_AVATAR, '');
        await pref.put(KEY_USERS_JSON, '[]');
        await pref.put(KEY_AUTH_TOKEN, '');
        await pref.flush();
      }
    } catch (error) {
      console.error('PreferenceService ensureDefaults failed.');
    }
  }

  static async isFirstLaunch(): Promise<boolean> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return true;
    }

    try {
      const value = await pref.get(KEY_IS_FIRST_LAUNCH, true);
      return value as boolean;
    } catch (error) {
      console.error('PreferenceService isFirstLaunch failed.');
      return true;
    }
  }

  static async setFirstLaunch(value: boolean): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      await pref.put(KEY_IS_FIRST_LAUNCH, value);
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService setFirstLaunch failed.');
    }
  }

  static async isLoggedIn(): Promise<boolean> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return false;
    }

    try {
      const value = await pref.get(KEY_IS_LOGGED_IN, false);
      return value as boolean;
    } catch (error) {
      console.error('PreferenceService isLoggedIn failed.');
      return false;
    }
  }

  static async setLoggedIn(value: boolean): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      await pref.put(KEY_IS_LOGGED_IN, value);
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService setLoggedIn failed.');
    }
  }

  static async getCurrentUserId(): Promise<number> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return -1;
    }

    try {
      const value = await pref.get(KEY_CURRENT_USER_ID, -1);
      return value as number;
    } catch (error) {
      console.error('PreferenceService getCurrentUserId failed.');
      return -1;
    }
  }

  static async setCurrentUserId(id: number): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      await pref.put(KEY_CURRENT_USER_ID, id);
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService setCurrentUserId failed.');
    }
  }

  static async getCurrentUsername(): Promise<string> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return '';
    }

    try {
      const value = await pref.get(KEY_CURRENT_USERNAME, '');
      return value as string;
    } catch (error) {
      console.error('PreferenceService getCurrentUsername failed.');
      return '';
    }
  }

  static async setCurrentUsername(username: string): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      await pref.put(KEY_CURRENT_USERNAME, username);
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService setCurrentUsername failed.');
    }
  }

  static async getCurrentAvatar(): Promise<string> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return '';
    }

    try {
      const value = await pref.get(KEY_CURRENT_AVATAR, '');
      return value as string;
    } catch (error) {
      console.error('PreferenceService getCurrentAvatar failed.');
      return '';
    }
  }

  static async setCurrentAvatar(avatar: string): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      await pref.put(KEY_CURRENT_AVATAR, avatar);
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService setCurrentAvatar failed.');
    }
  }

  static async getUsersJson(): Promise<string> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return '[]';
    }

    try {
      const value = await pref.get(KEY_USERS_JSON, '[]');
      return value as string;
    } catch (error) {
      console.error('PreferenceService getUsersJson failed.');
      return '[]';
    }
  }

  static async setUsersJson(value: string): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      await pref.put(KEY_USERS_JSON, value);
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService setUsersJson failed.');
    }
  }

  static async getAuthToken(): Promise<string> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return '';
    }

    try {
      const value = await pref.get(KEY_AUTH_TOKEN, '');
      return value as string;
    } catch (error) {
      console.error('PreferenceService getAuthToken failed.');
      return '';
    }
  }

  static async setAuthToken(token: string): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      await pref.put(KEY_AUTH_TOKEN, token);
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService setAuthToken failed.');
    }
  }

  static async logout(): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      await pref.put(KEY_IS_LOGGED_IN, false);
      await pref.put(KEY_CURRENT_USER_ID, -1);
      await pref.put(KEY_CURRENT_USERNAME, '');
      await pref.put(KEY_CURRENT_AVATAR, '');
      await pref.put(KEY_AUTH_TOKEN, '');
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService logout failed.');
    }
  }

  static async getNoteDraft(routeId: string): Promise<string> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return '';
    }

    try {
      const key = `${KEY_NOTE_DRAFT_PREFIX}${routeId || 'default'}`;
      const value = await pref.get(key, '');
      return value as string;
    } catch (error) {
      console.error('PreferenceService getNoteDraft failed.');
      return '';
    }
  }

  static async setNoteDraft(routeId: string, value: string): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      const key = `${KEY_NOTE_DRAFT_PREFIX}${routeId || 'default'}`;
      await pref.put(key, value);
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService setNoteDraft failed.');
    }
  }

  static async removeNoteDraft(routeId: string): Promise<void> {
    const pref: preferences.Preferences | null = PreferenceService.getPrefSafely();
    if (pref === null) {
      return;
    }

    try {
      const key = `${KEY_NOTE_DRAFT_PREFIX}${routeId || 'default'}`;
      await pref.delete(key);
      await pref.flush();
    } catch (error) {
      console.error('PreferenceService removeNoteDraft failed.');
    }
  }

  private static getPrefSafely(): preferences.Preferences | null {
    if (gPref === null) {
      console.error('PreferenceService is not initialized.');
      return null;
    }
    return gPref;
  }
}
