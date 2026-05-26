import router from '@ohos.router';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import { map, mapCommon, MapComponent } from '@kit.MapKit';
import RouteStore from '../common/service/RouteStore';
import { RealLocationService } from '../common/service/RealLocationService';
import { TravelRoute } from '../common/model/TravelRoute';
import { RoutePoint } from '../common/model/RoutePoint';
import { GeoUtil } from '../common/util/GeoUtil';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct RecordPage {
  private locationService: RealLocationService = new RealLocationService();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private locationPermissions: Array<Permissions> = [
    'ohos.permission.LOCATION',
    'ohos.permission.APPROXIMATELY_LOCATION'
  ];
  private mapController: map.MapComponentController | undefined = undefined;
  private routePolyline: map.MapPolyline | undefined = undefined;
  private mapCallback: ((err: BusinessError, mapController: map.MapComponentController) => void) | undefined = undefined;
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
  @State isRecording: boolean = false;
  @State totalDistance: number = 0;
  @State compassValue: number = 36;
  @State altitudeText: string = '0 m';
  @State mapStatusText: string = '地图初始化中';

  aboutToAppear(): void {
    this.initMapCallback();

    const route = new TravelRoute(`${Date.now()}`, `记录路线-${Date.now()}`);
    RouteStore.addRoute(route);
    this.routeId = route.id;
    this.routeTitle = route.title;
  }

  aboutToDisappear(): void {
    this.locationService.stop();
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
      this.redrawRouteOnMap();
    };
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

      this.mapStatusText = '定位权限未授权，无法记录真实轨迹';
      return false;
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

  private async startRecord(): Promise<void> {
    if (this.isRecording) {
      return;
    }

    const hasPermission = await this.ensureLocationPermission();
    if (!hasPermission) {
      return;
    }

    this.enableMyLocationLayer();
    this.isRecording = true;
    this.mapStatusText = '正在记录真实定位轨迹';
    this.locationService.start((point: RoutePoint) => {
      this.appendRoutePoint(point);
    }, (message: string) => {
      this.isRecording = false;
      this.mapStatusText = message;
    });
  }

  private pauseRecord(): void {
    this.isRecording = false;
    this.locationService.stop();
    this.mapStatusText = this.points.length > 0 ? '记录已暂停' : '地图已就绪，等待开始记录';
  }

  private addManualPoint(): void {
    const point = new RoutePoint(
      39.90 + this.points.length * 0.00015,
      116.39 + this.points.length * 0.00018,
      50 + this.points.length,
      Date.now(),
      '手工打点'
    );

    this.appendRoutePoint(point);
  }

  private appendRoutePoint(point: RoutePoint): void {
    this.points = [...this.points, point];
    RouteStore.appendPoint(this.routeId, point);
    this.totalDistance = GeoUtil.routeDistance(this.points);
    this.altitudeText = `${point.altitude} m`;
    this.compassValue = (this.compassValue + 17) % 360;
    this.mapStatusText = `已采集 ${this.points.length} 个轨迹点`;
    this.focusMapOnPoint(point);
    this.redrawRouteOnMap();
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

  build() {
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
      .width('100%');

      Text(this.routeTitle)
        .fontSize(16)
        .fontColor('#666666');

      Row() {
        Column({ space: 4 }) {
          Text('距离')
            .fontSize(13)
            .fontColor('#999999');
          Text(`${(this.totalDistance / 1000).toFixed(2)} km`)
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
          Text(`${this.compassValue}°`)
            .fontSize(20);
        }
        .layoutWeight(1);
      }
      .padding(14)
      .backgroundColor('#F4F7FB')
      .borderRadius(16)
      .width('100%');

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

          Column({ space: 4 }) {
            Text(this.mapStatusText)
              .fontSize(13)
              .fontColor('#1F2937')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(`已采集 ${this.points.length} 个点`)
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
        .height(240)
        .borderRadius(16)
        .clip(true);
      }
      .padding(10)
      .backgroundColor('#F8F8F8')
      .borderRadius(18)
      .width('100%');

      Row({ space: 8 }) {
        Button(this.isRecording ? '记录中...' : '开始记录')
          .layoutWeight(1)
          .enabled(!this.isRecording)
          .onClick(() => {
            this.startRecord();
          });

        Button('暂停')
          .layoutWeight(1)
          .onClick(() => {
            this.pauseRecord();
          });

        Button('手工打点')
          .layoutWeight(1)
          .onClick(() => {
            this.addManualPoint();
          });
      }

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

      Text(`轨迹点数量：${this.points.length}`)
        .fontSize(14);

      List({ space: 6 }) {
        ForEach(this.points, (item: RoutePoint, index: number) => {
          ListItem() {
            Text(`#${index + 1} 纬度:${item.lat.toFixed(5)} 经度:${item.lng.toFixed(5)} 海拔:${item.altitude}`)
              .fontSize(13)
              .padding(10)
              .width('100%')
              .backgroundColor('#FAFAFA')
              .borderRadius(10);
          }
        }, (item: RoutePoint, index?: number) => `${item.time}_${index}`);
      }
      .layoutWeight(1);
    }
    .padding(16)
    .width('100%')
    .height('100%');
  }
}
