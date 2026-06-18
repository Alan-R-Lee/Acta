import router from '@ohos.router';
import RouteStore from '../common/service/RouteStore';
import { TravelRoute } from '../common/model/TravelRoute';
import { TravelNote } from '../common/model/TravelNote';
import { TravelMemory } from '../common/model/TravelMemory';
import { TravelDataService } from '../common/service/TravelDataService';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct NoteEditorPage {
  @State routeId: string = '';
  @State title: string = '';
  @State content: string = '';
  @State imageList: string[] = [];
  @State routes: TravelRoute[] = [];
  @State selectedRouteTitle: string = '';
  @State routeName: string = '';
  @State routeMessage: string = '';
  @State memories: TravelMemory[] = [];

  async aboutToAppear(): Promise<void> {
    await TravelDataService.syncFromServer();
    const params = router.getParams() as Record<string, string> | null | undefined;
    this.routeId = params?.['routeId'] || '';
    this.routes = [...RouteStore.getRoutes()];

    if (!this.routeId && this.routes.length > 0) {
      this.routeId = this.routes[0].id;
    }

    const route = RouteStore.getRouteById(this.routeId);
    this.selectedRouteTitle = route ? route.title : '未关联路线';
    this.refreshMemories();
  }

  private refreshRoutes(): void {
    this.routes = [...RouteStore.getRoutes()];
    const route = RouteStore.getRouteById(this.routeId);
    this.selectedRouteTitle = route ? route.title : '未关联路线';
    this.refreshMemories();
  }

  private refreshMemories(): void {
    this.memories = this.routeId ? [...RouteStore.getMemoriesByRouteId(this.routeId)] : [];
  }

  private async createRoute(): Promise<void> {
    const name = this.routeName.trim();
    if (!name) {
      this.routeMessage = '请输入路线名称。';
      return;
    }

    const route = new TravelRoute(`${Date.now()}`, name);
    RouteStore.addRoute(route);
    await TravelDataService.createRoute(route);
    this.routeId = route.id;
    this.routeName = '';
    this.routeMessage = '已新建并关联当前行记。';
    this.refreshRoutes();
  }

  private selectRoute(routeId: string): void {
    this.routeId = routeId;
    this.routeMessage = '';
    this.refreshRoutes();
  }

  private addMockImage(): void {
    this.imageList = [...this.imageList, `/mock/image_${Date.now()}.png`];
  }

  private generateNoteFromMemories(): void {
    if (this.memories.length === 0) {
      this.routeMessage = '当前路线还没有可汇总的记忆点。';
      return;
    }

    const memoryLines: string[] = [];
    for (let i = 0; i < this.memories.length; i++) {
      const memory = this.memories[i];
      memoryLines.push(
        `${i + 1}. ${memory.title}（${memory.lat.toFixed(5)}, ${memory.lng.toFixed(5)}）：${memory.content || '这里还没有文字记录。'}`
      );
    }

    this.title = this.title || `${this.selectedRouteTitle} 行记`;
    this.content = `AI行记草稿：\n本次路线围绕 ${this.selectedRouteTitle} 展开，途中记录了 ${this.memories.length} 个记忆点。\n\n${memoryLines.join('\n')}\n\n可以继续补充天气、同行人、心情和路线亮点。`;
    this.routeMessage = '已根据记忆点生成行记草稿。';
  }

  private async saveNote(): Promise<void> {
    if (!this.routeId) {
      const route = new TravelRoute(`${Date.now()}`, this.title || '未命名路线');
      RouteStore.addRoute(route);
      await TravelDataService.createRoute(route);
      this.routeId = route.id;
      this.refreshRoutes();
    }

    const note = new TravelNote(
      `${Date.now()}`,
      this.routeId,
      this.title || '未命名行记',
      this.content
    );
    note.images = [...this.imageList];
    RouteStore.addNote(note);
    await TravelDataService.createNote(note);
    router.back();
  }

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from NoteEditorPage.');
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

        Text('行记写作')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1);
      }
      .width('100%');

      Text(`关联路线：${this.selectedRouteTitle}`)
        .fontSize(14)
        .fontColor('#666666');

      Column({ space: 10 }) {
        Text('新建关联路线')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .width('100%');

        Row({ space: 8 }) {
          TextInput({
            placeholder: '输入路线名称',
            text: this.routeName
          })
            .layoutWeight(1)
            .height(42)
            .onChange((value: string) => {
              this.routeName = value;
            });

          Button('新建')
            .height(42)
            .onClick(() => {
              void this.createRoute();
            });
        }
        .width('100%');

        if (this.routeMessage.length > 0) {
          Text(this.routeMessage)
            .fontSize(12)
            .fontColor(this.routeMessage === '请输入路线名称。' ? '#D9485F' : '#2BA471')
            .width('100%');
        }

        if (this.routes.length > 0) {
          Text('选择已有路线')
            .fontSize(13)
            .fontColor('#666666')
            .width('100%');

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.routes, (item: TravelRoute) => {
              Button(item.title)
                .height(34)
                .margin({
                  right: 8,
                  bottom: 8
                })
                .backgroundColor(item.id === this.routeId ? '#4A7BFF' : '#EEF2FF')
                .fontColor(item.id === this.routeId ? '#FFFFFF' : '#2F4B8F')
                .onClick(() => {
                  this.selectRoute(item.id);
                });
            }, (item: TravelRoute) => item.id);
          }
          .width('100%');
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F7F8FA')
      .borderRadius(12);

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(`路线记忆点：${this.memories.length}`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1);

          Button('AI汇总生成行记')
            .height(36)
            .fontSize(13)
            .enabled(this.memories.length > 0)
            .onClick(() => {
              this.generateNoteFromMemories();
            });
        }
        .width('100%');

        if (this.memories.length > 0) {
          List({ space: 6 }) {
            ForEach(this.memories, (item: TravelMemory, index: number) => {
              ListItem() {
                Column({ space: 4 }) {
                  Text(`${index + 1}. ${item.title}`)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1F2937');

                  Text(item.content || `位置：${item.lat.toFixed(5)}, ${item.lng.toFixed(5)}`)
                    .fontSize(12)
                    .fontColor('#6B7280')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                }
                .width('100%')
                .padding(8)
                .backgroundColor('#FFFFFF')
                .borderRadius(8);
              }
            }, (item: TravelMemory) => item.id);
          }
          .height(120);
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F4F7FB')
      .borderRadius(12);

      Text('标题')
        .fontSize(15)
        .fontWeight(FontWeight.Medium);

      TextInput({
        placeholder: '输入行记标题',
        text: this.title
      })
        .onChange((value: string) => {
          this.title = value;
        });

      Text('正文')
        .fontSize(15)
        .fontWeight(FontWeight.Medium);

      TextArea({
        placeholder: '记录旅途见闻、风景、路况和感受',
        text: this.content
      })
        .height(220)
        .onChange((value: string) => {
          this.content = value;
        });

      Button('添加图片（Demo占位）')
        .width('100%')
        .onClick(() => {
          this.addMockImage();
        });

      Text(`已添加图片：${this.imageList.length}`)
        .fontSize(14);

      if (this.imageList.length > 0) {
        List({ space: 6 }) {
          ForEach(this.imageList, (item: string, index: number) => {
            ListItem() {
              Text(`图片${index + 1}：${item}`)
                .fontSize(13)
                .padding(10)
                .width('100%')
                .backgroundColor('#FAFAFA')
                .borderRadius(10);
            }
          }, (item: string) => item);
        }
        .height(120);
      }

      Button('保存行记')
        .width('100%')
        .onClick(() => {
          void this.saveNote();
        });
    }
    .padding(16)
    .width('100%')
    .height('100%');
  }
}
