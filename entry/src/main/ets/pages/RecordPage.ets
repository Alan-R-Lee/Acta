import router from '@ohos.router';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import geoLocationManager from '@ohos.geoLocationManager';
import sensor from '@ohos.sensor';
import promptAction from '@ohos.promptAction';
import { map, mapCommon, MapComponent } from '@kit.MapKit';
import RouteStore from '../common/service/RouteStore';
import { RealLocationService } from '../common/service/RealLocationService';
import { TravelRoute } from '../common/model/TravelRoute';
import { RoutePoint } from '../common/model/RoutePoint';
import { TravelMemory } from '../common/model/TravelMemory';
import { GeoUtil } from '../common/util/GeoUtil';
import { BackChevronIcon } from '../common/component/BackChevronIcon';
import { TravelDataService } from '../common/service/TravelDataService';

@Entry
@Component
struct RecordPage {
  private locationService: RealLocationService = new RealLocationService();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private foregroundLocationPermissions: Array<Permissions> = [
    'ohos.permission.LOCATION',
    'ohos.permission.APPROXIMATELY_LOCATION'
  ];
  private backgroundLocationPermission: Permissions = 'ohos.permission.LOCATION_IN_BACKGROUND';
  private mapController: map.MapComponentController | undefined = undefined;
  private routePolyline: map.MapPolyline | undefined = undefined;
  private mapCallback: ((err: BusinessError, mapController: map.MapComponentController) => void) | undefined = undefined;
  private endPressTimer: number = -1;
  private metricTimer: number = -1;
  private orientationCallback: ((data: sensor.OrientationResponse) => void) | undefined = undefined;
  private barometerCallback: ((data: sensor.BarometerResponse) => void) | undefined = undefined;
  private targetHeading: number = 36;
  private displayedHeading: number = 36;
  private latestAltitude: number | undefined = undefined;
  private hasReliableAltitude: boolean = false;
  private mapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: 39.908823,
        longitude: 116.397470
      },
      zoom: 16
    },
    mapType: mapCommon.MapType.STANDARD,
    myLocationControlsEnabled: true,
    scaleControlsEnabled: true
  };

  @State routeId: string = '';
  @State routeTitle: string = '未命名路线';
  @State points: RoutePoint[] = [];
  @State hasStarted: boolean = false;
  @State isRecording: boolean = false;
  @State isPaused: boolean = false;
  @State endProgress: number = 0;
  @State isHoldingEnd: boolean = false;
  @State totalDistance: number = 0;
  @State compassValue: number = 36;
  @State altitudeText: string = '0 m';
  @State distanceText: string = '0.00 m';
  @State compassText: string = '东北 9°';
  @State mapStatusText: string = '地图初始化中';
  @State memories: TravelMemory[] = [];
  @State showSaveSheet: boolean = false;
  @State pendingRouteTitle: string = '';

  async aboutToAppear(): Promise<void> {
    this.initMapCallback();
    this.startMetricTimer();
    this.startDirectionSensors();
    this.refreshMemories();
  }

  onPageShow(): void {
    this.startMetricTimer();
    this.startDirectionSensors();
    this.refreshMemories();
    void this.redrawRouteOnMap();
    if (this.isRecording) {
      this.mapStatusText = '正在记录真实定位轨迹';
      void this.showUserLocationOnMap();
    }
  }

  aboutToDisappear(): void {
    this.cancelEndHold();
    this.stopMetricTimer();
    this.stopDirectionSensors();
    if (!this.isRecording) {
      this.locationService.stop();
    }
    if (this.routePolyline) {
      this.routePolyline.remove();
      this.routePolyline = undefined;
    }
  }

  private initMapCallback(): void {
    this.mapCallback = (err: BusinessError, mapController: map.MapComponentController): void => {
      if (err) {
        this.mapStatusText = `地图初始化失败：${err.message || err.code}`;
        return;
      }

      this.mapController = mapController;
      this.mapStatusText = '地图已就绪，等待开始记录';
      void this.showUserLocationOnMap();
      this.redrawRouteOnMap();
    };
  }

  private async showUserLocationOnMap(): Promise<void> {
    const hasPermission = await this.ensureLocationPermission();
    if (!hasPermission) {
      return;
    }

    this.enableMyLocationLayer();
    await this.focusMapOnCurrentLocation();
    if (!this.isRecording && !this.isPaused) {
      this.mapStatusText = '已显示当前位置，等待开始记录';
    }
  }

  private async focusMapOnCurrentLocation(): Promise<void> {
    if (!this.mapController) {
      return;
    }

    try {
      const location = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.UNSET,
        maxAccuracy: 50
      });
      const point = new RoutePoint(
        location.latitude,
        location.longitude,
        typeof location.altitude === 'number' && Number.isFinite(location.altitude) ? location.altitude : 0,
        Date.now(),
        '当前位置',
        typeof location.altitudeAccuracy === 'number' ? location.altitudeAccuracy : undefined
      );
      await this.focusMapOnPoint(point);
    } catch (error) {
      console.error('Failed to focus map on current location.');
    }
  }

  private async ensureLocationPermission(): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();

    try {
      const result = await atManager.requestPermissionsFromUser(this.context, this.foregroundLocationPermissions);
      let hasForegroundPermission = false;
      for (let i = 0; i < result.authResults.length; i++) {
        const granted = result.authResults[i] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
        if (granted) {
          hasForegroundPermission = true;
        }
      }

      if (!hasForegroundPermission) {
        this.mapStatusText = '定位权限未授权，无法记录真实轨迹';
        return false;
      }

      const backgroundResult = await atManager.requestPermissionsFromUser(this.context, [this.backgroundLocationPermission]);
      const hasBackgroundPermission = backgroundResult.authResults.some((value: number) => {
        return value === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      });
      if (!hasBackgroundPermission && !this.isRecording && !this.isPaused) {
        this.mapStatusText = '未授予后台定位权限，息屏或切换应用时可能中断记录';
      }
      return true;
    } catch (error) {
      const err = error as BusinessError;
      this.mapStatusText = `定位权限申请失败：${err.message || err.code}`;
      return false;
    }
  }

  private enableMyLocationLayer(): void {
    if (!this.mapController) {
      return;
    }

    try {
      this.mapController.setMyLocationEnabled(true);
      this.mapController.setMyLocationControlsEnabled(true);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Failed to enable my location layer: ${err.message || err.code}`);
    }
  }

  private startMetricTimer(): void {
    if (this.metricTimer >= 0) {
      return;
    }

    this.updateRealtimeMetrics();
    this.metricTimer = setInterval(() => {
      this.updateRealtimeMetrics();
    }, 16);
  }

  private stopMetricTimer(): void {
    if (this.metricTimer >= 0) {
      clearInterval(this.metricTimer);
      this.metricTimer = -1;
    }
  }

  private updateRealtimeMetrics(): void {
    this.displayedHeading = this.smoothHeading(this.displayedHeading, this.targetHeading);
    this.compassValue = Math.round(this.displayedHeading) % 360;
    this.distanceText = `${this.totalDistance.toFixed(2)} m`;
    this.compassText = this.formatHeading(this.compassValue);

    if (this.hasReliableAltitude && typeof this.latestAltitude === 'number') {
      this.altitudeText = `${this.latestAltitude.toFixed(0)} m`;
    }
  }

  private smoothHeading(current: number, target: number): number {
    const delta = ((target - current + 540) % 360) - 180;
    return (current + delta * 0.22 + 360) % 360;
  }

  private formatHeading(degrees: number): string {
    const normalized = (Math.round(degrees) + 360) % 360;
    const labels: string[] = ['正北', '东北', '正东', '东南', '正南', '西南', '正西', '西北'];
    const nearestIndex = Math.round(normalized / 45) % 8;
    const baseDegrees = nearestIndex * 45;
    const offset = Math.abs(((normalized - baseDegrees + 540) % 360) - 180);
    return `${labels[nearestIndex]}  ${offset}°`;
  }

  private startDirectionSensors(): void {
    if (!this.orientationCallback) {
      const callback = (data: sensor.OrientationResponse): void => {
        if (Number.isFinite(data.alpha)) {
          this.targetHeading = (data.alpha + 360) % 360;
        }
      };

      try {
        sensor.on(sensor.SensorId.ORIENTATION, callback, { interval: 'ui' });
        this.orientationCallback = callback;
      } catch (error) {
        console.error('Failed to subscribe orientation sensor.');
      }
    }

    if (!this.barometerCallback) {
      const callback = (data: sensor.BarometerResponse): void => {
        if (this.hasReliableAltitude || !Number.isFinite(data.pressure) || data.pressure <= 0) {
          return;
        }

        this.latestAltitude = 44330 * (1 - Math.pow(data.pressure / 1013.25, 0.1903));
        this.altitudeText = `${this.latestAltitude.toFixed(0)} m`;
      };

      try {
        sensor.on(sensor.SensorId.BAROMETER, callback, { interval: 'normal' });
        this.barometerCallback = callback;
      } catch (error) {
        console.error('Failed to subscribe barometer sensor.');
      }
    }
  }

  private stopDirectionSensors(): void {
    if (this.orientationCallback) {
      try {
        sensor.off(sensor.SensorId.ORIENTATION, this.orientationCallback);
      } catch (error) {
        console.error('Failed to unsubscribe orientation sensor.');
      }
      this.orientationCallback = undefined;
    }

    if (this.barometerCallback) {
      try {
        sensor.off(sensor.SensorId.BAROMETER, this.barometerCallback);
      } catch (error) {
        console.error('Failed to unsubscribe barometer sensor.');
      }
      this.barometerCallback = undefined;
    }
  }

  private async startRecord(): Promise<void> {
    if (this.isRecording) {
      return;
    }

    const hasPermission = await this.ensureLocationPermission();
    if (!hasPermission) {
      return;
    }

    if (!this.routeId) {
      const route = new TravelRoute(`${Date.now()}`, `记录路线-${Date.now()}`);
      RouteStore.addRoute(route);
      await TravelDataService.createRoute(route);
      this.routeId = route.id;
      this.routeTitle = route.title;
    }

    await this.showUserLocationOnMap();
    this.hasStarted = true;
    this.isRecording = true;
    this.isPaused = false;
    this.mapStatusText = '正在记录真实定位轨迹';
    this.locationService.start((point: RoutePoint) => {
      this.appendRoutePoint(point);
    }, (message: string) => {
      this.isRecording = false;
      this.isPaused = true;
      this.mapStatusText = message;
    });
  }

  private pauseRecord(): void {
    if (!this.hasStarted || this.isPaused) {
      return;
    }

    this.isRecording = false;
    this.isPaused = true;
    this.locationService.stop();
    this.mapStatusText = this.points.length > 0 ? '记录已暂停' : '地图已就绪，等待开始记录';
  }

  private resumeRecord(): void {
    if (!this.hasStarted || !this.isPaused) {
      return;
    }

    this.enableMyLocationLayer();
    this.isRecording = true;
    this.isPaused = false;
    this.mapStatusText = '正在继续记录真实定位轨迹';
    this.locationService.start((point: RoutePoint) => {
      this.appendRoutePoint(point);
    }, (message: string) => {
      this.isRecording = false;
      this.isPaused = true;
      this.mapStatusText = message;
    });
  }

  private togglePauseRecord(): void {
    if (this.isPaused) {
      this.resumeRecord();
      return;
    }

    this.pauseRecord();
  }

  private finishRecord(): void {
    this.cancelEndHold();
    this.locationService.stop();
    this.hasStarted = false;
    this.isRecording = false;
    this.isPaused = false;
    this.mapStatusText = this.points.length > 0 ? '路线记录已结束' : '未采集轨迹，记录已结束';
    if (!this.routeId) {
      return;
    }

    if (this.points.length === 0) {
      RouteStore.deleteRoute(this.routeId);
      void TravelDataService.deleteRoute(this.routeId);
      this.routeId = '';
      this.routeTitle = '未命名路线';
      promptAction.showToast({ message: '未记录到轨迹，已取消保存' });
      return;
    }

    this.pendingRouteTitle = this.routeTitle.startsWith('记录路线-') ? '' : this.routeTitle;
    this.showSaveSheet = true;
  }

  private async confirmSaveRoute(): Promise<void> {
    if (!this.routeId) {
      this.showSaveSheet = false;
      return;
    }

    const title = this.pendingRouteTitle.trim() || `路线 ${new Date().toLocaleString()}`;
    const summary = `轨迹点 ${this.points.length} 个，里程 ${(this.totalDistance / 1000).toFixed(2)} km`;
    RouteStore.updateRouteTitle(this.routeId, title);
    RouteStore.updateRouteSummary(this.routeId, summary);
    const route = RouteStore.getRouteById(this.routeId);
    if (route) {
      route.title = title;
      route.summary = summary;
      await TravelDataService.updateRoute(route);
    }
    this.routeTitle = title;
    this.showSaveSheet = false;
    promptAction.showToast({ message: '路线已保存' });
    try {
      router.pushUrl({
        url: 'pages/NoteComposePage',
        params: {
          routeId: this.routeId
        }
      });
    } catch (error) {
      console.error('Failed to navigate to NoteComposePage after saving route.');
    }
  }

  private async cancelSaveRoute(): Promise<void> {
    if (this.routeId) {
      RouteStore.deleteRoute(this.routeId);
      await TravelDataService.deleteRoute(this.routeId);
    }
    this.routeId = '';
    this.routeTitle = '未命名路线';
    this.pendingRouteTitle = '';
    this.showSaveSheet = false;
    promptAction.showToast({ message: '已取消保存路线' });
  }

  private startEndHold(): void {
    if (!this.hasStarted || this.endPressTimer >= 0) {
      return;
    }

    this.isHoldingEnd = true;
    this.endProgress = 0;
    this.endPressTimer = setInterval(() => {
      const nextProgress = Math.min(100, this.endProgress + 4);
      this.endProgress = nextProgress;
      if (nextProgress >= 100) {
        this.finishRecord();
      }
    }, 48);
  }

  private cancelEndHold(): void {
    if (this.endPressTimer >= 0) {
      clearInterval(this.endPressTimer);
      this.endPressTimer = -1;
    }
    this.isHoldingEnd = false;
    this.endProgress = 0;
  }

  private async addMemoryPoint(): Promise<void> {
    const point = await this.getMemoryLocationPoint();
    if (!point) {
      return;
    }

    this.openMemoryEditor(point);
  }

  private refreshMemories(): void {
    if (!this.routeId) {
      this.memories = [];
      return;
    }

    this.memories = RouteStore.getMemoriesByRouteId(this.routeId);
  }

  private formatMemoryTime(time: number): string {
    const date = new Date(time);
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private async getMemoryLocationPoint(): Promise<RoutePoint | undefined> {
    if (this.points.length > 0) {
      const latestPoint = this.points[this.points.length - 1];
      return new RoutePoint(
        latestPoint.lat,
        latestPoint.lng,
        latestPoint.altitude,
        Date.now(),
        '记忆点',
        latestPoint.altitudeAccuracy
      );
    }

    const hasPermission = await this.ensureLocationPermission();
    if (!hasPermission) {
      return undefined;
    }

    try {
      this.mapStatusText = '正在获取当前位置';
      const location = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.UNSET,
        maxAccuracy: 50
      });
      const altitudeAccuracy: number | undefined = typeof location.altitudeAccuracy === 'number'
        ? location.altitudeAccuracy
        : undefined;
      const altitude: number = typeof location.altitude === 'number' && Number.isFinite(location.altitude)
        ? location.altitude
        : (typeof this.latestAltitude === 'number' ? this.latestAltitude : 0);
      return new RoutePoint(location.latitude, location.longitude, altitude, Date.now(), '记忆点', altitudeAccuracy);
    } catch (error) {
      const err = error as BusinessError;
      this.mapStatusText = `获取当前位置失败：${err.message || err.code}`;
      return undefined;
    }
  }

  private openMemoryEditor(point: RoutePoint): void {
    try {
      router.pushUrl({
        url: 'pages/MemoryEditorPage',
        params: {
          routeId: this.routeId,
          pointTime: point.time,
          lat: point.lat,
          lng: point.lng,
          altitude: point.altitude
        }
      });
    } catch (error) {
      console.error('Failed to navigate to MemoryEditorPage.');
    }
  }

  private appendRoutePoint(point: RoutePoint): void {
    this.points = [...this.points, point];
    RouteStore.appendPoint(this.routeId, point);
    void TravelDataService.appendPoint(this.routeId, point);
    this.totalDistance = GeoUtil.routeDistance(this.points);
    this.updateAltitudeFromPoint(point);
    this.updateRealtimeMetrics();
    this.mapStatusText = `路线记录中，已更新 ${this.points.length} 次定位`;
    this.focusMapOnPoint(point);
    this.redrawRouteOnMap();
  }

  private updateAltitudeFromPoint(point: RoutePoint): void {
    const hasVerticalAccuracy = typeof point.altitudeAccuracy === 'number' && Number.isFinite(point.altitudeAccuracy);
    const hasNonZeroAltitude = Math.abs(point.altitude) > 0.1;
    if (!hasVerticalAccuracy && !hasNonZeroAltitude) {
      return;
    }

    this.latestAltitude = point.altitude;
    this.hasReliableAltitude = true;
    this.altitudeText = `${point.altitude.toFixed(0)} m`;
  }

  private async focusMapOnPoint(point: RoutePoint): Promise<void> {
    if (!this.mapController) {
      return;
    }

    try {
      const target = await this.toMapLatLng(point);
      const cameraUpdate = map.newCameraPosition({
        target: target,
        zoom: 17
      });
      this.mapController.animateCamera(cameraUpdate, 600);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Failed to move map camera: ${err.message || err.code}`);
    }
  }

  private async redrawRouteOnMap(): Promise<void> {
    if (!this.mapController || this.points.length < 2) {
      return;
    }

    try {
      const mapPoints = await this.buildMapRoutePoints();
      if (this.routePolyline) {
        this.routePolyline.remove();
      }

      this.routePolyline = await this.mapController.addPolyline({
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
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Failed to redraw route on map: ${err.message || err.code}`);
    }
  }

  private async buildMapRoutePoints(): Promise<mapCommon.LatLng[]> {
    const mapPoints: mapCommon.LatLng[] = [];
    for (let i = 0; i < this.points.length; i++) {
      mapPoints.push(await this.toMapLatLng(this.points[i]));
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

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from RecordPage.');
    }
  }

  @Builder
  private EndHoldButton() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({
        value: this.endProgress,
        total: 100,
        type: ProgressType.Ring
      })
        .width(76)
        .height(76)
        .color('#EF4444')
        .backgroundColor('#FEE2E2');

      Button('结束')
        .width(62)
        .height(62)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor('#EF4444')
        .borderRadius(31)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.startEndHold();
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            if (this.endProgress < 100) {
              this.cancelEndHold();
            }
          }
        });
    }
    .width(84)
    .height(84);
  }

  @Builder
  private RecordControls() {
    Stack({ alignContent: Alignment.Center }) {
      if (!this.hasStarted) {
        Button('GO')
          .width(112)
          .height(56)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('#16A34A')
          .borderRadius(28)
          .onClick(() => {
            this.startRecord();
          })
          .transition({
            type: TransitionType.Insert,
            opacity: 0,
            scale: { x: 0.88, y: 0.88 }
          });
      } else {
        Row({ space: 22 }) {
          if (this.isPaused) {
            Button('继续记录')
              .width(112)
              .height(56)
              .fontSize(18)
              .fontColor('#FFFFFF')
              .backgroundColor('#2563EB')
              .borderRadius(28)
              .onClick(() => {
                this.togglePauseRecord();
              });
          } else {
            Button('暂停')
              .width(96)
              .height(56)
              .fontSize(18)
              .fontColor('#FFFFFF')
              .backgroundColor('#F59E0B')
              .borderRadius(28)
              .onClick(() => {
                this.togglePauseRecord();
              });
          }

          this.EndHoldButton();
        }
        .justifyContent(FlexAlign.Center)
        .transition({
          type: TransitionType.Insert,
          opacity: 0,
          translate: { x: 0, y: 12 },
          scale: { x: 0.86, y: 0.86 }
        });
      }
    }
    .width('100%')
    .height(94)
    .animation({
      duration: 280,
      curve: Curve.EaseInOut
    });
  }

  @Builder
  private SaveRouteSheet() {
    Column({ space: 14 }) {
      Text('保存路线')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827');

      Text('为这条路线命名，保存后可在首页和行记页面找到。')
        .fontSize(13)
        .fontColor('#6B7280')
        .width('100%');

      TextInput({
        placeholder: '输入路线名称',
        text: this.pendingRouteTitle
      })
        .width('100%')
        .height(48)
        .backgroundColor('#F8FAFC')
        .borderRadius(12)
        .onChange((value: string) => {
          this.pendingRouteTitle = value;
        });

      Row({ space: 10 }) {
        Button('取消保存')
          .layoutWeight(1)
          .backgroundColor('#E5E7EB')
          .fontColor('#374151')
          .onClick(() => {
            void this.cancelSaveRoute();
          });

        Button('保存路线')
          .layoutWeight(1)
          .backgroundColor('#16A34A')
          .fontColor('#FFFFFF')
          .onClick(() => {
            void this.confirmSaveRoute();
          });
      }
      .width('100%');
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 24, topRight: 24 });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 12 }) {
        Row({ space: 10 }) {
        Button() {
          BackChevronIcon();
        }
          .width(40)
          .height(40)
          .backgroundColor('#F3F4F6')
          .borderRadius(20)
          .onClick(() => {
            this.goBack();
          });

        Text('路线记录')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1);
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16
      });

      Text(this.routeTitle)
        .fontSize(16)
        .fontColor('#666666')
        .padding({
          left: 16,
          right: 16
        })
        .width('100%');

      Row() {
        Column({ space: 4 }) {
          Text('距离')
            .fontSize(13)
            .fontColor('#999999');
          Text(this.distanceText)
            .fontSize(20);
        }
        .layoutWeight(1);

        Column({ space: 4 }) {
          Text('海拔')
            .fontSize(13)
            .fontColor('#999999');
          Text(this.altitudeText)
            .fontSize(20);
        }
        .layoutWeight(1);

        Column({ space: 4 }) {
          Text('指南针')
            .fontSize(13)
            .fontColor('#999999');
          Text(this.compassText)
            .fontSize(20);
        }
        .layoutWeight(1);
      }
      .padding(14)
      .backgroundColor('#F4F7FB')
      .borderRadius(16)
      .width('100%')
      .margin({
        left: 16,
        right: 16
      });

      Column({ space: 8 }) {
        Text('实时地图 / 轨迹区域')
          .fontSize(14)
          .fontColor('#888888');

        Stack({ alignContent: Alignment.BottomStart }) {
          MapComponent({
            mapOptions: this.mapOptions,
            mapCallback: this.mapCallback
          })
            .width('100%')
            .height('100%');

          if (this.isPaused) {
            Column() {
              Text('路线记录已暂停')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF');
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#66000000');
          }

          Column({ space: 4 }) {
            Text(this.mapStatusText)
              .fontSize(13)
              .fontColor('#1F2937')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(this.isRecording ? '路线记录中' : '路线记录待开始')
              .fontSize(12)
              .fontColor('#4B5563');
          }
          .padding({
            left: 12,
            right: 12,
            top: 8,
            bottom: 8
          })
          .margin({
            left: 10,
            bottom: 10
          })
          .backgroundColor('#DFFFFFFF')
          .borderRadius(10);
        }
        .width('100%')
        .height(430)
        .borderRadius(16)
        .clip(true);
      }
      .padding({
        top: 10,
        bottom: 10
      })
      .backgroundColor('#F8F8F8')
      .borderRadius(18)
      .width('100%');

      this.RecordControls();

      Row({ space: 8 }) {
        Button('查看详情')
          .layoutWeight(1)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/RouteDetailPage',
              params: {
                routeId: this.routeId
              }
            });
          });

        Button('AI分析')
          .layoutWeight(1)
          .onClick(() => {
            router.pushUrl({ url: 'pages/AiPage' });
          });
      }
      .padding({
        left: 16,
        right: 16
      });

        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text('位置记忆')
                .fontSize(16)
                .fontWeight(FontWeight.Medium);

              Text(`已保存 ${this.memories.length} 个记忆点`)
                .fontSize(12)
                .fontColor('#6B7280');
            }
            .layoutWeight(1);

            Button('添加记忆点')
              .height(40)
              .fontSize(14)
              .backgroundColor('#16A34A')
              .fontColor('#FFFFFF')
              .borderRadius(20)
              .onClick(() => {
                this.addMemoryPoint();
              });
          }
          .width('100%');

          if (this.memories.length === 0) {
            Text('暂无记忆点')
              .fontSize(14)
              .fontColor('#6B7280')
              .padding(14)
              .width('100%')
              .backgroundColor('#F8FAFC')
              .borderRadius(12);
          } else {
            ForEach(this.memories, (memory: TravelMemory) => {
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(`${memory.lat.toFixed(5)}, ${memory.lng.toFixed(5)}`)
                    .fontSize(13)
                    .fontColor('#1F2937')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });

                  Text(`海拔 ${memory.altitude.toFixed(0)} m`)
                    .fontSize(12)
                    .fontColor('#6B7280');

                  Text(this.formatMemoryTime(memory.createdAt))
                    .fontSize(12)
                    .fontColor('#9CA3AF');
                }
                .width('44%');

                Column({ space: 4 }) {
                  Text(memory.title)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#111827')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });

                  Text(memory.content || '未填写记忆内容')
                    .fontSize(12)
                    .fontColor('#4B5563')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                }
                .layoutWeight(1);
              }
              .padding(14)
              .width('100%')
              .backgroundColor('#F8FAFC')
              .borderRadius(12);
            }, (memory: TravelMemory) => memory.id);
          }
        }
        .padding({
          left: 16,
          right: 16
        })
        .width('100%');
        }
        .padding({
          top: 0,
          bottom: 16
        })
        .width('100%');
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto);

      if (this.showSaveSheet) {
        Column() {
          Blank()
            .layoutWeight(1)
            .width('100%')
            .backgroundColor('#55000000')
            .onClick(() => {
              void this.cancelSaveRoute();
            });

          this.SaveRouteSheet();
        }
        .width('100%')
        .height('100%');
      }
    }
  }
}
