import router from '@ohos.router';
import RouteStore from '../common/service/RouteStore';
import { MockLocationService } from '../common/service/MockLocationService';
import { TravelRoute } from '../common/model/TravelRoute';
import { RoutePoint } from '../common/model/RoutePoint';
import { GeoUtil } from '../common/util/GeoUtil';

@Entry
@Component
struct RecordPage {
  private locationService: MockLocationService = new MockLocationService();

  @State routeId: string = '';
  @State routeTitle: string = '未命名路线';
  @State points: RoutePoint[] = [];
  @State isRecording: boolean = false;
  @State totalDistance: number = 0;
  @State compassValue: number = 36;
  @State altitudeText: string = '0 m';

  aboutToAppear(): void {
    const route = new TravelRoute(`${Date.now()}`, `记录路线-${Date.now()}`);
    RouteStore.addRoute(route);
    this.routeId = route.id;
    this.routeTitle = route.title;
  }

  aboutToDisappear(): void {
    this.locationService.stop();
  }

  private startRecord(): void {
    if (this.isRecording) {
      return;
    }

    this.isRecording = true;
    this.locationService.start((point: RoutePoint) => {
      this.points = [...this.points, point];
      this.altitudeText = `${point.altitude} m`;
      this.compassValue = (this.compassValue + 17) % 360;
      RouteStore.appendPoint(this.routeId, point);
      this.totalDistance = GeoUtil.routeDistance(this.points);
    });
  }

  private pauseRecord(): void {
    this.isRecording = false;
    this.locationService.stop();
  }

  private addManualPoint(): void {
    const point = new RoutePoint(
      39.90 + this.points.length * 0.00015,
      116.39 + this.points.length * 0.00018,
      50 + this.points.length,
      Date.now(),
      '手工打点'
    );

    this.points = [...this.points, point];
    RouteStore.appendPoint(this.routeId, point);
    this.totalDistance = GeoUtil.routeDistance(this.points);
    this.altitudeText = `${point.altitude} m`;
  }

  build() {
    Column({ space: 12 }) {
      Text('路线记录')
        .fontSize(26)
        .fontWeight(FontWeight.Bold);

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
        Text('地图 / 轨迹区域（Demo占位）')
          .fontSize(14)
          .fontColor('#888888');

        Stack() {
          Column({ space: 6 }) {
            Text('这里后续可替换为真实地图 SDK')
              .fontSize(16);
            Text('当前展示为轨迹记录占位层')
              .fontSize(13)
              .fontColor('#777777');
            Text(`已采集 ${this.points.length} 个点`)
              .fontSize(14);
          }
        }
        .width('100%')
        .height(220)
        .backgroundColor('#E8F3E8')
        .borderRadius(16);
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