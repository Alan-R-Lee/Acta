import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        console.error(`Failed to load page. Code: ${err.code}, msg: ${err.message}`);
        return;
      }
      console.info('Succeeded in loading SplashPage.');
    });
  }
}