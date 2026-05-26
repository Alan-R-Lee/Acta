import router from '@ohos.router';
import { BusinessError } from '@ohos.base';
import { map, mapCommon, MapComponent } from '@kit.MapKit';
import RouteStore from '../common/service/RouteStore';
import { TravelRoute } from '../common/model/TravelRoute';
import { PreferenceService } from '../common/service/PreferenceService';
import common from '@ohos.app.ability.common';

@Entry
@Component
struct HomePage {
  @State routeName: string = '';
  @State searchText: string = '';
  @State routes: TravelRoute[] = [];
  @State currentUsername: string = '';

  @State headerHeight: number = 92;
  @State headerOpacity: number = 1.0;
  @State lastOffset: number = 0;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private mapPreviewController: map.MapComponentController | undefined = undefined;
  private mapPreviewCallback: ((err: BusinessError, mapController: map.MapComponentController) => void) | undefined = undefined;
  private mapPreviewOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: 39.908823,
        longitude: 116.397470
      },
      zoom: 11
    },
    mapType: mapCommon.MapType.STANDARD,
    scaleControlsEnabled: true
  };

  async aboutToAppear(): Promise<void> {
    this.initMapPreviewCallback();
    this.refresh();
    await this.loadCurrentUser();
  }

  private initMapPreviewCallback(): void {
    this.mapPreviewCallback = (err: BusinessError, mapController: map.MapComponentController): void => {
      if (err) {
        console.error(`Failed to init home map preview: ${err.message || err.code}`);
        return;
      }

      this.mapPreviewController = mapController;
    };
  }

  private refresh(): void {
    this.routes = [...RouteStore.getRoutes()];
  }

  private async loadCurrentUser(): Promise<void> {
    try {
      await PreferenceService.init(this.context);
      await PreferenceService.ensureDefaults();
      this.currentUsername = await PreferenceService.getCurrentUsername();
    } catch (error) {
      this.currentUsername = '';
    }
  }

  private createRoute(): void {
    const name: string = this.routeName.trim();
    if (!name) {
      return;
    }

    const route: TravelRoute = new TravelRoute(`${Date.now()}`, name);
    RouteStore.addRoute(route);
    this.routeName = '';
    this.refresh();
  }

  private async logout(): Promise<void> {
    try {
      await PreferenceService.logout();
      router.replaceUrl({
        url: 'pages/AuthPage'
      });
    } catch (error) {
      console.error('Logout failed.');
    }
  }

  private goRecord(): void {
    try {
      router.pushUrl({ url: 'pages/RecordPage' });
    } catch (error) {
      console.error('Failed to navigate to RecordPage.');
    }
  }

  private goNote(): void {
    try {
      router.pushUrl({ url: 'pages/NoteEditorPage' });
    } catch (error) {
      console.error('Failed to navigate to NoteEditorPage.');
    }
  }

  private goAi(): void {
    try {
      router.pushUrl({ url: 'pages/AiPage' });
    } catch (error) {
      console.error('Failed to navigate to AiPage.');
    }
  }

  private goRouteDetail(routeId: string): void {
    try {
      router.pushUrl({
        url: 'pages/RouteDetailPage',
        params: {
          routeId: routeId
        }
      });
    } catch (error) {
      console.error('Failed to navigate to RouteDetailPage.');
    }
  }

  @Builder
  private HeaderBar() {
    Row() {
      Text('☰')
        .fontSize(26)
        .fontColor('#1F2937')
        .width(42)
        .height(42)
        .textAlign(TextAlign.Center)
        .backgroundColor('#22FFFFFF')
        .borderRadius(21);

      Text('Acta')
        .fontSize(29)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .layoutWeight(1)
        .textAlign(TextAlign.Center);

      Text(
        this.currentUsername && this.currentUsername.length > 0
          ? `欢迎回来，${this.currentUsername}`
          : '登录/注册'
      )
        .fontSize(14)
        .fontColor('#1F2937')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(112)
        .textAlign(TextAlign.End);
    }
    .width('100%')
    .height(this.headerHeight)
    .padding({
      left: 18,
      right: 18,
      top: 34,
      bottom: 10
    })
    .backgroundColor('#CCFFFFFF')
    .opacity(this.headerOpacity)
    .animation({
      duration: 220,
      curve: Curve.EaseInOut
    });
  }

  @Builder
  private SearchBox() {
    Row({ space: 8 }) {
      Text('⌕')
        .fontSize(18)
        .fontColor('#666666');

      TextInput({
        placeholder: '搜索路线、行记、地点',
        text: this.searchText
      })
        .layoutWeight(1)
        .backgroundColor('#00FFFFFF')
        .fontSize(14)
        .onChange((value: string) => {
          this.searchText = value;
        });
    }
    .height(46)
    .padding({
      left: 16,
      right: 16
    })
    .margin({
      left: 18,
      right: 18,
      top: 10
    })
    .backgroundColor('#CCFFFFFF')
    .borderRadius(23);
  }

  @Builder
  private MapArea() {
    Stack({ alignContent: Alignment.TopStart }) {
      MapComponent({
        mapOptions: this.mapPreviewOptions,
        mapCallback: this.mapPreviewCallback
      })
        .width('100%')
        .height('100%');

      Column({ space: 8 }) {
        Text('地图预览')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937');

        Text(`已保存路线 ${this.routes.length} 条`)
          .fontSize(13)
          .fontColor('#4B5563');

        Text('进入记录页开始采集真实轨迹')
          .fontSize(12)
          .fontColor('#6B7280');
      }
      .padding(14)
      .margin({
        left: 18,
        top: 72
      })
      .backgroundColor('#DFFFFFFF')
      .borderRadius(12);

      Row({ space: 8 }) {
        TextInput({
          placeholder: '输入路线名称',
          text: this.routeName
        })
          .layoutWeight(1)
          .height(38)
          .backgroundColor('#EFFFFFFF')
          .borderRadius(19)
          .onChange((value: string) => {
            this.routeName = value;
          });

        Button('新建')
          .height(38)
          .onClick(() => {
            this.createRoute();
          });
      }
      .width('92%')
      .position({
        x: 16,
        y: 18
      });
    }
    .width('100%')
    .height(430)
    .clip(true)
    .margin({
      top: 12
    });
  }

  @Builder
  private ActionButtons() {
    Row({ space: 12 }) {
      Button('进入记录页')
        .layoutWeight(1)
        .height(46)
        .borderRadius(23)
        .onClick(() => {
          this.goRecord();
        });

      Button('AI')
        .layoutWeight(1)
        .height(46)
        .borderRadius(23)
        .onClick(() => {
          this.goAi();
        });

      Button('写行记')
        .layoutWeight(1)
        .height(46)
        .borderRadius(23)
        .onClick(() => {
          this.goNote();
        });
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18
    })
    .margin({
      top: -66
    });
  }

  @Builder
  private SavedRoutes() {
    Column({ space: 12 }) {
      Text('已保存路线')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .padding({
          left: 18,
          right: 18
        });

      if (this.routes.length === 0) {
        Column({ space: 8 }) {
          Text('还没有路线')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2937');

          Text('先创建一条路线，或者进入记录页自动生成演示路线。')
            .fontSize(14)
            .fontColor('#888888');
        }
        .width('90%')
        .padding(22)
        .backgroundColor('#F7F8FA')
        .borderRadius(18);
      } else {
        ForEach(this.routes, (item: TravelRoute) => {
          Column({ space: 6 }) {
            Text(item.title)
              .fontSize(19)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1F2937');

            Text(item.summary || '暂无路线摘要')
              .fontSize(14)
              .fontColor('#777777')
              .maxLines(2);

            Text(`轨迹点：${item.points.length}`)
              .fontSize(12)
              .fontColor('#999999');
          }
          .width('90%')
          .padding(16)
          .backgroundColor('#F6F6F6')
          .borderRadius(16)
          .onClick(() => {
            this.goRouteDetail(item.id);
          });
        }, (item: TravelRoute) => item.id);
      }

      Blank()
        .height(30);
    }
    .width('100%')
    .padding({
      top: 40
    })
    .backgroundColor('#FFFFFF');
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          Column() {
            this.HeaderBar();

            this.SearchBox();

            this.MapArea();

            this.ActionButtons();
          }
          .width('100%')
          .height(720)
          .backgroundColor('#F2F6F3');

          this.SavedRoutes();
        }
        .width('100%');
      }
      .width('100%')
      .height('100%')
      .onScroll((xOffset: number, yOffset: number) => {
        if (yOffset > this.lastOffset + 6) {
          this.headerHeight = 58;
          this.headerOpacity = 0.92;
        } else if (yOffset < this.lastOffset - 6) {
          this.headerHeight = 92;
          this.headerOpacity = 1.0;
        }

        this.lastOffset = yOffset;
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP]);
  }
}
