import router from '@ohos.router';
import RouteStore from '../common/service/RouteStore';
import { TravelRoute } from '../common/model/TravelRoute';
import { AiService } from '../common/service/AiService';
import { TravelDataService } from '../common/service/TravelDataService';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct AiPage {
  @State routes: TravelRoute[] = [];
  @State selectedId: string = '';
  @State result: string = '请选择路线并生成 AI 路书分析。';
  @State isGenerating: boolean = false;

  async aboutToAppear(): Promise<void> {
    await TravelDataService.syncFromServer();
    this.routes = [...RouteStore.getRoutes()];
    if (this.routes.length > 0) {
      this.selectedId = this.routes[0].id;
    }
  }

  private async generate(): Promise<void> {
    const route = RouteStore.getRouteById(this.selectedId);
    if (!route) {
      this.result = '未找到路线数据。';
      return;
    }

    this.isGenerating = true;
    this.result = '正在生成 AI 路书分析...';
    try {
      const text = await AiService.generateRouteInsightAsync(route);
      this.result = text;
      RouteStore.updateRouteSummary(route.id, text);
      await TravelDataService.updateRouteSummary(route.id, text);
    } finally {
      this.isGenerating = false;
    }
  }

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from AiPage.');
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

        Text('AI 路书助手')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1);
      }
      .width('100%');

      Text('当前已接入云端 AI 分析入口，生成内容会同步回路线摘要。')
        .fontSize(13)
        .fontColor('#666666');

      if (this.routes.length === 0) {
        Text('暂无路线，请先创建路线或进入记录页生成数据。')
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

        Button(this.isGenerating ? '生成中...' : '生成分析')
          .width('100%')
          .enabled(!this.isGenerating)
          .onClick(() => {
            void this.generate();
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
