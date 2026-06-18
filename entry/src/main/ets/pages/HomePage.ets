import router from '@ohos.router';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { BusinessError } from '@ohos.base';
import { map, mapCommon, MapComponent } from '@kit.MapKit';
import RouteStore from '../common/service/RouteStore';
import { RealLocationService } from '../common/service/RealLocationService';
import { TravelRoute } from '../common/model/TravelRoute';
import { RoutePoint } from '../common/model/RoutePoint';
import { PreferenceService } from '../common/service/PreferenceService';
import { TravelDataService } from '../common/service/TravelDataService';
import common from '@ohos.app.ability.common';

@Entry
@Component
struct HomePage {
  @State searchText: string = '';
  @State routes: TravelRoute[] = [];
  @State currentUsername: string = '';
  @State currentAvatar: string = '';

  @State headerHeight: number = 64;
  @State headerOpacity: number = 1.0;
  @State lastOffset: number = 0;
  @State mapPreviewStatus: string = '地图初始化中';
  @State isSidebarOpen: boolean = false;
  @State shouldShowSidebarLayer: boolean = false;
  @State aiPulseScale: number = 1;
  @State aiPulseOpacity: number = 0.32;
  @State aiOrbRotation: number = 0;
  @State aiCoreScale: number = 1;

  private locationService: RealLocationService = new RealLocationService();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private locationPermissions: Array<Permissions> = [
    'ohos.permission.LOCATION',
    'ohos.permission.APPROXIMATELY_LOCATION'
  ];
  private mapPreviewController: map.MapComponentController | undefined = undefined;
  private mapPreviewPolyline: map.MapPolyline | undefined = undefined;
  private mapPreviewCallback: ((err: BusinessError, mapController: map.MapComponentController) => void) | undefined = undefined;
  private aiPulseTimer: number = -1;
  private mapPreviewOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: 39.908823,
        longitude: 116.397470
      },
      zoom: 11
    },
    mapType: mapCommon.MapType.STANDARD,
    myLocationControlsEnabled: true,
    scaleControlsEnabled: true
  };

  async aboutToAppear(): Promise<void> {
    this.initMapPreviewCallback();
    this.startAiOrbAnimation();
    await TravelDataService.syncFromServer();
    this.refresh();
    await this.loadCurrentUser();
    await this.updateMapPreview();
  }

  async onPageShow(): Promise<void> {
    await TravelDataService.syncFromServer();
    this.refresh();
    await this.loadCurrentUser();
    await this.updateMapPreview();
  }

  aboutToDisappear(): void {
    this.locationService.stop();
    this.clearMapPreviewRoute();
    this.stopAiOrbAnimation();
  }

  private initMapPreviewCallback(): void {
    this.mapPreviewCallback = (err: BusinessError, mapController: map.MapComponentController): void => {
      if (err) {
        console.error(`Failed to init home map preview: ${err.message || err.code}`);
        return;
      }

      this.mapPreviewController = mapController;
      this.updateMapPreview();
    };
  }

  private refresh(): void {
    this.routes = [...RouteStore.getRoutes()];
  }

  private async updateMapPreview(): Promise<void> {
    if (!this.mapPreviewController) {
      return;
    }

    const latestRoute = this.getLatestRoute();
    if (latestRoute) {
      this.locationService.stop();
      await this.showLatestRoute(latestRoute);
      return;
    }

    this.clearMapPreviewRoute();
    await this.showCurrentLocation();
  }

  private getLatestRoute(): TravelRoute | undefined {
    return this.routes.length > 0 ? this.routes[0] : undefined;
  }

  private async showCurrentLocation(): Promise<void> {
    const hasPermission = await this.ensureLocationPermission();
    if (!hasPermission) {
      return;
    }

    this.enableMyLocationLayer();
    this.mapPreviewStatus = '正在显示当前位置';
    this.locationService.start((point: RoutePoint) => {
      this.focusMapOnPoint(point, 17);
      this.mapPreviewStatus = `当前位置：${point.lat.toFixed(5)}, ${point.lng.toFixed(5)}`;
    }, (message: string) => {
      this.mapPreviewStatus = message;
    });
  }

  private async showLatestRoute(route: TravelRoute): Promise<void> {
    this.clearMapPreviewRoute();
    this.mapPreviewStatus = `正在展示最新路线：${route.title}`;

    if (route.points.length === 0) {
      this.mapPreviewStatus = `最新路线暂无轨迹点：${route.title}`;
      return;
    }

    if (route.points.length === 1) {
      await this.focusMapOnPoint(route.points[0], 16);
      return;
    }

    try {
      const mapPoints = await this.buildMapRoutePoints(route.points);
      this.mapPreviewPolyline = await this.mapPreviewController?.addPolyline({
        points: mapPoints,
        color: 0xFF2B7FFF,
        width: 12,
        clickable: false,
        visible: true,
        zIndex: 10,
        geodesic: false,
        jointType: mapCommon.JointType.ROUND,
        startCap: mapCommon.CapStyle.BUTT,
        endCap: mapCommon.CapStyle.BUTT
      });
      await this.focusMapOnRoute(route.points);
    } catch (error) {
      const err = error as BusinessError;
      this.mapPreviewStatus = `展示路线失败：${err.message || err.code}`;
    }
  }

  private clearMapPreviewRoute(): void {
    if (!this.mapPreviewPolyline) {
      return;
    }

    this.mapPreviewPolyline.remove();
    this.mapPreviewPolyline = undefined;
  }

  private async ensureLocationPermission(): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();

    try {
      const result = await atManager.requestPermissionsFromUser(this.context, this.locationPermissions);
      for (let i = 0; i < result.authResults.length; i++) {
        if (result.authResults[i] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          return true;
        }
      }

      this.mapPreviewStatus = '定位权限未授权，无法显示当前位置';
      return false;
    } catch (error) {
      const err = error as BusinessError;
      this.mapPreviewStatus = `定位权限申请失败：${err.message || err.code}`;
      return false;
    }
  }

  private enableMyLocationLayer(): void {
    if (!this.mapPreviewController) {
      return;
    }

    try {
      this.mapPreviewController.setMyLocationEnabled(true);
      this.mapPreviewController.setMyLocationControlsEnabled(true);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Failed to enable home my location layer: ${err.message || err.code}`);
    }
  }

  private async focusMapOnRoute(points: RoutePoint[]): Promise<void> {
    if (points.length === 0) {
      return;
    }

    let minLat = points[0].lat;
    let maxLat = points[0].lat;
    let minLng = points[0].lng;
    let maxLng = points[0].lng;

    for (let i = 1; i < points.length; i++) {
      minLat = Math.min(minLat, points[i].lat);
      maxLat = Math.max(maxLat, points[i].lat);
      minLng = Math.min(minLng, points[i].lng);
      maxLng = Math.max(maxLng, points[i].lng);
    }

    const center = new RoutePoint((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    const span = Math.max(maxLat - minLat, maxLng - minLng);
    const zoom = span > 0.08 ? 11 : span > 0.025 ? 13 : span > 0.006 ? 15 : 16;
    await this.focusMapOnPoint(center, zoom);
  }

  private async focusMapOnPoint(point: RoutePoint, zoom: number): Promise<void> {
    if (!this.mapPreviewController) {
      return;
    }

    try {
      const target = await this.toMapLatLng(point);
      const cameraUpdate = map.newCameraPosition({
        target: target,
        zoom: zoom
      });
      this.mapPreviewController.animateCamera(cameraUpdate, 600);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Failed to move home map camera: ${err.message || err.code}`);
    }
  }

  private async buildMapRoutePoints(points: RoutePoint[]): Promise<mapCommon.LatLng[]> {
    const mapPoints: mapCommon.LatLng[] = [];
    for (let i = 0; i < points.length; i++) {
      mapPoints.push(await this.toMapLatLng(points[i]));
    }
    return mapPoints;
  }

  private async toMapLatLng(point: RoutePoint): Promise<mapCommon.LatLng> {
    const rawPoint: mapCommon.LatLng = {
      latitude: point.lat,
      longitude: point.lng
    };

    try {
      return await map.convertCoordinate(
        mapCommon.CoordinateType.WGS84,
        mapCommon.CoordinateType.GCJ02,
        rawPoint
      );
    } catch (error) {
      return rawPoint;
    }
  }

  private async loadCurrentUser(): Promise<void> {
    try {
      await PreferenceService.init(this.context);
      await PreferenceService.ensureDefaults();
      this.currentUsername = await PreferenceService.getCurrentUsername();
      this.currentAvatar = await PreferenceService.getCurrentAvatar();
    } catch (error) {
      this.currentUsername = '';
      this.currentAvatar = '';
    }
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

  private openSidebar(): void {
    if (this.isSidebarOpen) {
      return;
    }

    this.shouldShowSidebarLayer = true;
    animateTo({
      duration: 260,
      curve: Curve.EaseOut
    }, () => {
      this.isSidebarOpen = true;
    });
  }

  private closeSidebar(): void {
    if (!this.shouldShowSidebarLayer) {
      return;
    }

    animateTo({
      duration: 220,
      curve: Curve.EaseInOut
    }, () => {
      this.isSidebarOpen = false;
    });
    setTimeout(() => {
      if (!this.isSidebarOpen) {
        this.shouldShowSidebarLayer = false;
      }
    }, 240);
  }

  private goSidebarPage(url: string): void {
    this.closeSidebar();
    try {
      router.pushUrl({ url: url });
    } catch (error) {
      console.error(`Failed to navigate to ${url}.`);
    }
  }

  private startAiOrbAnimation(): void {
    if (this.aiPulseTimer >= 0) {
      return;
    }

    this.aiPulseTimer = setInterval(() => {
      animateTo({
        duration: 900,
        curve: Curve.Linear
      }, () => {
        this.aiOrbRotation = (this.aiOrbRotation + 120) % 360;
        if (this.aiPulseScale > 1) {
          this.aiPulseScale = 1;
          this.aiPulseOpacity = 0.32;
          this.aiCoreScale = 1;
        } else {
          this.aiPulseScale = 1.18;
          this.aiPulseOpacity = 0.08;
          this.aiCoreScale = 0.9;
        }
      });
    }, 900);
  }

  private stopAiOrbAnimation(): void {
    if (this.aiPulseTimer < 0) {
      return;
    }

    clearInterval(this.aiPulseTimer);
    this.aiPulseTimer = -1;
  }

  onBackPress(): boolean {
    if (this.isSidebarOpen) {
      this.closeSidebar();
      return true;
    }

    return false;
  }

  @Builder
  private HeaderBar() {
    Row() {
      Button() {
        Text('☰')
          .fontSize(24)
          .fontColor('#1F2937')
          .textAlign(TextAlign.Center);
      }
        .width(42)
        .height(42)
        .backgroundColor('#22FFFFFF')
        .borderRadius(21)
        .onClick(() => {
          this.openSidebar();
        });

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
        .textAlign(TextAlign.End)
        .onClick(() => {
          this.goSidebarPage('pages/UserInfoPage');
        });
    }
    .width('100%')
    .height(this.headerHeight)
    .padding({
      left: 18,
      right: 18,
      top: 0,
      bottom: 0
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
        Text(this.routes.length > 0 ? '最新路线预览' : '当前位置预览')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937');

        Text(`已保存路线 ${this.routes.length} 条`)
          .fontSize(13)
          .fontColor('#4B5563');

        Text(this.mapPreviewStatus)
          .fontSize(12)
          .fontColor('#6B7280')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .padding(14)
      .margin({
        left: 18,
        top: 18
      })
      .backgroundColor('#DFFFFFFF')
      .borderRadius(12);
    }
    .width('100%')
    .height(560)
    .clip(true)
    .margin({
      top: 12
    });
  }

  @Builder
  private BottomIconAction(icon: Resource, label: string, onTap: () => void) {
    Column({ space: 3 }) {
      Image(icon)
        .width(38)
        .height(38)
        .objectFit(ImageFit.Contain);

      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#082B68')
        .textAlign(TextAlign.Center);
    }
    .layoutWeight(1)
    .height(66)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      onTap();
    });
  }

  @Builder
  private AiOrbAction() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(68)
        .height(68)
        .fill('#0A84FF')
        .opacity(this.aiPulseOpacity)
        .scale({
          x: this.aiPulseScale,
          y: this.aiPulseScale
        });

      Circle()
        .width(58)
        .height(58)
        .fill('#0A84FF');

      Circle()
        .width(38)
        .height(38)
        .fill('#2EA7FF')
        .opacity(0.82)
        .scale({
          x: this.aiCoreScale,
          y: this.aiCoreScale
        });

      Circle()
        .width(15)
        .height(15)
        .fill('#FFFFFF')
        .opacity(0.92);

      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(7)
          .height(7)
          .fill('#D9F0FF')
          .offset({
            x: 20,
            y: -20
          });
      }
      .width(58)
      .height(58)
      .rotate({
        angle: this.aiOrbRotation
      });
    }
    .layoutWeight(1)
    .height(74)
    .onClick(() => {
      this.goAi();
    });
  }

  @Builder
  private ActionButtons() {
    Row({ space: 8 }) {
      this.BottomIconAction($r('app.media.tab_route'), '路线', () => {
        this.goRecord();
      });

      this.AiOrbAction();

      this.BottomIconAction($r('app.media.tab_note'), '行记', () => {
        this.goNote();
      });
    }
    .width('100%')
    .height(96)
    .padding({
      left: 22,
      right: 22,
      top: 8,
      bottom: 14
    })
    .backgroundColor('#FDFDFD')
    .border({
      width: { top: 1 },
      color: '#E5E7EB'
    });
  }

  @Builder
  private SidebarIcon(label: string, bgColor: string) {
    Text(label)
      .fontSize(22)
      .fontColor('#FFFFFF')
      .width(46)
      .height(46)
      .textAlign(TextAlign.Center)
      .backgroundColor(bgColor)
      .borderRadius(23);
  }

  @Builder
  private SidebarItem(icon: string, title: string, url: string) {
    Row({ space: 16 }) {
      Text(icon)
        .fontSize(24)
        .fontColor('#2F3437')
        .width(32)
        .textAlign(TextAlign.Center);

      Text(title)
        .fontSize(22)
        .fontColor('#2F3437')
        .layoutWeight(1);

      Text('>')
        .fontSize(20)
        .fontColor('#B6BDC3');
    }
    .width('100%')
    .height(64)
    .padding({
      left: 24,
      right: 22
    })
    .onClick(() => {
      this.goSidebarPage(url);
    });
  }

  @Builder
  private SidebarLayer() {
    if (this.shouldShowSidebarLayer) {
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .opacity(this.isSidebarOpen ? 1 : 0)
          .animation({
            duration: 220,
            curve: Curve.EaseOut
          })
          .onClick(() => {
            this.closeSidebar();
          });

        Column() {
          Column({ space: 12 }) {
            if (this.currentAvatar.length > 0) {
              Image(this.currentAvatar)
                .width(86)
                .height(86)
                .objectFit(ImageFit.Cover)
                .borderRadius(43);
            } else {
              Text(this.currentUsername && this.currentUsername.length > 0
                ? this.currentUsername.substring(0, 1).toUpperCase()
                : 'A')
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .width(86)
                .height(86)
                .textAlign(TextAlign.Center)
                .backgroundColor('#0A84FF')
                .borderRadius(43);
            }

            Text(this.currentUsername && this.currentUsername.length > 0 ? this.currentUsername : 'Acta 用户')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1F2937');
          }
          .width('100%')
          .padding({
            top: 52,
            bottom: 30
          });

          Row() {
            Column({ space: 8 }) {
              this.SidebarIcon('👤', '#0A84FF');
              Text('用户')
                .fontSize(16)
                .fontColor('#2F3437');
            }
            .layoutWeight(1)
            .onClick(() => {
              this.goSidebarPage('pages/UserInfoPage');
            });

            Column({ space: 8 }) {
              this.SidebarIcon('⚙', '#22C55E');
              Text('设置')
                .fontSize(16)
                .fontColor('#2F3437');
            }
            .layoutWeight(1)
            .onClick(() => {
              this.goSidebarPage('pages/SettingsPage');
            });

            Column({ space: 8 }) {
              this.SidebarIcon('?', '#F59E0B');
              Text('帮助')
                .fontSize(16)
                .fontColor('#2F3437');
            }
            .layoutWeight(1)
            .onClick(() => {
              this.goSidebarPage('pages/HelpPage');
            });
          }
          .width('100%')
          .padding({
            left: 18,
            right: 18,
            bottom: 26
          });

          Divider()
            .strokeWidth(1)
            .color('#EEF0F2');

          this.SidebarItem('👤', '用户', 'pages/UserInfoPage');
          this.SidebarItem('⚙', '设置', 'pages/SettingsPage');
          this.SidebarItem('?', '帮助', 'pages/HelpPage');
        }
        .width('78%')
        .height('100%')
        .backgroundColor('#FFFFFF')
        .translate({
          x: this.isSidebarOpen ? 0 : -320,
          y: 0
        })
        .animation({
          duration: 260,
          curve: Curve.EaseOut
        });
      }
      .width('100%')
      .height('100%');
    }
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

          Text('进入写行记页面新建路线，或进入记录页采集真实轨迹。')
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
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column() {
          Column() {
            this.HeaderBar();

            this.SearchBox();

            this.MapArea();
          }
          .width('100%')
          .height(770)
          .backgroundColor('#F2F6F3');

          this.SavedRoutes();

          Blank()
            .height(96);
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
          this.headerHeight = 64;
          this.headerOpacity = 1.0;
        }

        this.lastOffset = yOffset;
      });

      this.ActionButtons();

      this.SidebarLayer();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }
}
