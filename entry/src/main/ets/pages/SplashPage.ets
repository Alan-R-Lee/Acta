import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { PreferenceService } from '../common/service/PreferenceService';

@Entry
@Component
struct SplashPage {
  @State seasonIndex: number = 0;
  @State blackMaskOpacity: number = 1.0;
  @State hasRouted: boolean = false;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.initSeason();
    this.startSplashFlow();
  }

  private initSeason(): void {
    const month: number = new Date().getMonth() + 1;

    if (month >= 3 && month <= 5) {
      this.seasonIndex = 0;
    } else if (month >= 6 && month <= 8) {
      this.seasonIndex = 1;
    } else if (month >= 9 && month <= 11) {
      this.seasonIndex = 2;
    } else {
      this.seasonIndex = 3;
    }
  }

  private async startSplashFlow(): Promise<void> {
    let isFirstLaunch: boolean = true;
    let isLoggedIn: boolean = false;

    try {
      await PreferenceService.init(this.context);
      await PreferenceService.ensureDefaults();

      isFirstLaunch = await PreferenceService.isFirstLaunch();
      isLoggedIn = await PreferenceService.isLoggedIn();
    } catch (error) {
      isFirstLaunch = true;
      isLoggedIn = false;
    }

    // 先等页面真正渲染出来，再开始淡入
    setTimeout(() => {
      this.blackMaskOpacity = 0.0;
    }, 200);

    // 开机图停留
    setTimeout(() => {
      this.startFadeOut(isFirstLaunch, isLoggedIn);
    }, 2400);
  }

  private startFadeOut(isFirstLaunch: boolean, isLoggedIn: boolean): void {
    if (this.hasRouted) {
      return;
    }

    // 黑色遮罩淡入，形成“开机图淡出到黑屏”
    this.blackMaskOpacity = 1.0;

    // 等遮罩动画完成后再跳转
    setTimeout(() => {
      if (this.hasRouted) {
        return;
      }

      this.hasRouted = true;

      if (isFirstLaunch || !isLoggedIn) {
        this.goAuth();
      } else {
        this.goHome();
      }
    }, 1400);
  }

  private goAuth(): void {
    try {
      router.replaceUrl({
        url: 'pages/AuthPage'
      });
    } catch (error) {
      console.error('Failed to navigate to AuthPage.');
    }
  }

  private goHome(): void {
    try {
      router.replaceUrl({
        url: 'pages/HomePage'
      });
    } catch (error) {
      console.error('Failed to navigate to HomePage.');
    }
  }

  @Builder
  private SeasonalImage() {
    if (this.seasonIndex === 0) {
      Image($r('app.media.splash_spring'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill);
    } else if (this.seasonIndex === 1) {
      Image($r('app.media.splash_summer'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill);
    } else if (this.seasonIndex === 2) {
      Image($r('app.media.splash_autumn'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill);
    } else {
      Image($r('app.media.splash_winter'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill);
    }
  }

  build() {
    Stack() {
      this.SeasonalImage();

      // 全屏轻微暗化
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#10000000');


      // 黑色遮罩：负责淡入淡出
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(this.blackMaskOpacity)
        .animation({
          duration: 1000,
          curve: Curve.EaseInOut
        });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }
}