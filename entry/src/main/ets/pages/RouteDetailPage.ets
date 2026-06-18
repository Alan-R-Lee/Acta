import router from '@ohos.router';
import RouteStore from '../common/service/RouteStore';
import { TravelRoute } from '../common/model/TravelRoute';
import { RoutePoint } from '../common/model/RoutePoint';
import { GeoUtil } from '../common/util/GeoUtil';
import { ShareService } from '../common/service/ShareService';
import { TravelDataService } from '../common/service/TravelDataService';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct RouteDetailPage {
  @State route: TravelRoute | undefined = undefined;
  @State shareText: string = '';

  async aboutToAppear(): Promise<void> {
    await TravelDataService.syncFromServer();
    let routeId: string = '';

    try {
      const params: Object = router.getParams();
      const safeParams: Record<string, Object> = params as Record<string, Object>;
      const value: Object | undefined = safeParams['routeId'];
      routeId = typeof value === 'string' ? value : '';
    } catch (error) {
      console.error('Failed to get router params.');
      routeId = '';
    }

    const currentRoute: TravelRoute | undefined = RouteStore.getRouteById(routeId);
    this.route = currentRoute;

    if (currentRoute) {
      this.shareText = ShareService.buildShareText(currentRoute);
    } else {
      this.shareText = '未找到对应路线。';
    }
  }

  private goToNoteEditor(): void {
    try {
      router.pushUrl({
        url: 'pages/NoteEditorPage',
        params: {
          routeId: this.route ? this.route.id : ''
        }
      });
    } catch (error) {
      console.error('Failed to navigate to NoteEditorPage.');
    }
  }

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from RouteDetailPage.');
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

        Text(this.route?.title || '路线详情')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%');

      Text(this.route?.summary || '暂无路线摘要')
        .fontSize(14)
        .fontColor('#666666');

      Row() {
        Column({ space: 4 }) {
          Text('轨迹点数')
            .fontSize(12)
            .fontColor('#999999');
          Text(`${this.route?.points.length || 0}`)
            .fontSize(20);
        }
        .layoutWeight(1);

        Column({ space: 4 }) {
          Text('总里程')
            .fontSize(12)
            .fontColor('#999999');
          Text(`${((this.route ? GeoUtil.routeDistance(this.route.points) : 0) / 1000).toFixed(2)} km`)
            .fontSize(20);
        }
        .layoutWeight(1);
      }
      .padding(14)
      .backgroundColor('#F6F8FB')
      .borderRadius(16)
      .width('100%');

      Text('分享文案')
        .fontSize(18)
        .fontWeight(FontWeight.Medium);

      Text(this.shareText)
        .fontSize(14)
        .padding(14)
        .width('100%')
        .backgroundColor('#F7F8FA')
        .borderRadius(12);

      Button('去写行记')
        .width('100%')
        .onClick(() => {
          this.goToNoteEditor();
        });

      if (this.route && this.route.points.length > 0) {
        Text('轨迹点明细')
          .fontSize(18)
          .fontWeight(FontWeight.Medium);

        List({ space: 6 }) {
          ForEach(this.route.points, (item: RoutePoint, index: number) => {
            ListItem() {
              Text(
                `#${index + 1} 纬度:${item.lat.toFixed(5)} 经度:${item.lng.toFixed(5)} 海拔:${item.altitude}m`
              )
                .fontSize(13)
                .padding(10)
                .width('100%')
                .backgroundColor('#FAFAFA')
                .borderRadius(10);
            }
          }, (item: RoutePoint, index?: number) => `${item.time}_${index}`)
        }
        .width('100%')
        .layoutWeight(1);
      }
    }
    .padding(16)
    .width('100%')
    .height('100%');
  }
}
