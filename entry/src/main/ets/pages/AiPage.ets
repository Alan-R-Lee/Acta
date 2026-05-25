import RouteStore from '../common/service/RouteStore';
import { TravelRoute } from '../common/model/TravelRoute';
import { AiService } from '../common/service/AiService';

@Entry
@Component
struct AiPage {
  @State routes: TravelRoute[] = [];
  @State selectedId: string = '';
  @State result: string = '请选择路线并生成 AI 路书分析。';

  aboutToAppear(): void {
    this.routes = [...RouteStore.getRoutes()];
    if (this.routes.length > 0) {
      this.selectedId = this.routes[0].id;
    }
  }

  private generate(): void {
    const route = RouteStore.getRouteById(this.selectedId);
    if (!route) {
      this.result = '未找到路线数据。';
      return;
    }

    const text = AiService.generateRouteInsight(route);
    this.result = text;
    RouteStore.updateRouteSummary(route.id, text);
  }

  build() {
    Column({ space: 12 }) {
      Text('AI 路书助手')
        .fontSize(26)
        .fontWeight(FontWeight.Bold);

      Text('演示版：本地分析规则，可替换为云端大模型接口')
        .fontSize(13)
        .fontColor('#666666');

      if (this.routes.length === 0) {
        Text('暂无路线，请先创建路线或进入记录页生成演示数据。')
          .fontSize(14)
          .padding(14)
          .backgroundColor('#F7F8FA')
          .borderRadius(12);
      } else {
        List({ space: 8 }) {
          ForEach(this.routes, (item: TravelRoute) => {
            ListItem() {
              Row({ space: 8 }) {
                Radio({ value: item.id, group: 'routeGroup' })
                  .checked(this.selectedId === item.id)
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      this.selectedId = item.id;
                    }
                  });

                Column({ space: 2 }) {
                  Text(item.title)
                    .fontSize(16);

                  Text(`轨迹点：${item.points.length}`)
                    .fontSize(12)
                    .fontColor('#999999');
                }
              }
              .padding(10)
              .width('100%')
              .backgroundColor('#FAFAFA')
              .borderRadius(10);
            }
          }, (item: TravelRoute) => item.id);
        }
        .height(220);

        Button('生成分析')
          .width('100%')
          .onClick(() => {
            this.generate();
          });
      }

      Text(this.result)
        .fontSize(14)
        .padding(14)
        .width('100%')
        .backgroundColor('#F5F7FB')
        .borderRadius(12);
    }
    .padding(16)
    .width('100%')
    .height('100%');
  }
}