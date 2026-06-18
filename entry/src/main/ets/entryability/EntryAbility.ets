import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { BusinessError } from '@ohos.base';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(false);
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#FFFFFF',
        navigationBarColor: '#FFFFFF',
        statusBarContentColor: '#111827',
        isStatusBarLightIcon: false
      });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Failed to configure main window. Code: ${err.code}, msg: ${err.message}`);
    }

    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        console.error(`Failed to load page. Code: ${err.code}, msg: ${err.message}`);
        return;
      }
      console.info('Succeeded in loading SplashPage.');
    });
  }
}
