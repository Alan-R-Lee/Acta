import router from '@ohos.router';
import RouteStore from '../common/service/RouteStore';
import { TravelRoute } from '../common/model/TravelRoute';
import { TravelNote } from '../common/model/TravelNote';
import { TravelDataService } from '../common/service/TravelDataService';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

interface NoteComposeParams {
  routeId?: string;
  noteId?: string;
}

@Entry
@Component
struct NoteEditorPage {
  @State routes: TravelRoute[] = [];
  @State notes: TravelNote[] = [];
  @State noteCounts: Record<string, number> = {};
  @State showFloatingCreate: boolean = false;

  async aboutToAppear(): Promise<void> {
    await TravelDataService.syncFromServer();
    this.refresh();
  }

  private refresh(): void {
    const routes = [...RouteStore.getRoutes()];
    routes.sort((a: TravelRoute, b: TravelRoute) => b.createdAt - a.createdAt);
    this.routes = routes;

    const notes = [...RouteStore.getAllNotes()];
    notes.sort((a: TravelNote, b: TravelNote) => b.createdAt - a.createdAt);
    this.notes = notes;

    const counts: Record<string, number> = {};
    routes.forEach((route: TravelRoute) => {
      counts[route.id] = RouteStore.getNotesByRouteId(route.id).length;
    });
    this.noteCounts = counts;
  }

  private openNewNote(routeId?: string, noteId?: string): void {
    try {
      const params: NoteComposeParams = {};
      if (routeId) {
        params.routeId = routeId;
      }
      if (noteId) {
        params.noteId = noteId;
      }

      router.pushUrl({
        url: 'pages/NoteComposePage',
        params: params
      });
    } catch (error) {
      console.error('Failed to navigate to NoteComposePage.');
    }
  }

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from NoteEditorPage.');
    }
  }

  private buildMeta(route: TravelRoute): string {
    const noteCount = this.noteCounts[route.id] || 0;
    const pointCount = route.points.length;
    return `${pointCount} 个轨迹点 · ${noteCount} 篇行记`;
  }

  private buildNoteMeta(note: TravelNote): string {
    const route = RouteStore.getRouteById(note.routeId);
    return route ? route.title : '未关联路线';
  }

  @Builder
  private NewNoteCard() {
    Column({ space: 12 }) {
      Text('+')
        .fontSize(36)
        .fontWeight(FontWeight.Lighter)
        .fontColor('#143129');

      Text('新的行记')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#143129');

      Text('从一条已保存路线开始写，或先进入写作页再关联路线。')
        .fontSize(13)
        .fontColor('#5B6B66')
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .padding({ top: 28, bottom: 28, left: 20, right: 20 })
    .backgroundColor('#E5F1EB')
    .borderRadius(28)
    .onClick(() => {
      this.openNewNote();
    });
  }

  @Builder
  private SavedNoteCard(note: TravelNote) {
    Column({ space: 8 }) {
      Text(note.title || '未命名行记')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#14221D')
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Text(this.buildNoteMeta(note))
        .fontSize(13)
        .fontColor('#6B7280')
        .width('100%');

      Text(note.content || '这篇行记还没有正文。')
        .fontSize(14)
        .fontColor('#495057')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Text(`图片 ${note.images.length} 张`)
        .fontSize(12)
        .fontColor('#7A8794')
        .width('100%');
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFF8EC')
    .borderRadius(24)
    .onClick(() => {
      this.openNewNote(note.routeId, note.id);
    });
  }

  @Builder
  private RouteCard(route: TravelRoute) {
    Column({ space: 10 }) {
      Row() {
        Text(route.title || '未命名路线')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%');

      Text(route.summary || '还没有路线摘要，进入后可以直接开始写这条路线的行记。')
        .fontSize(14)
        .fontColor('#52606D')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Row() {
        Text(this.buildMeta(route))
          .fontSize(13)
          .fontColor('#7A8794')
          .layoutWeight(1);

        Text('去写行记')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F766E');
      }
      .width('100%');
    }
    .width('100%')
    .padding({ top: 22, bottom: 22, left: 20, right: 20 })
    .backgroundColor('#FFFFFF')
    .borderRadius(28)
    .shadow({
      radius: 24,
      color: '#16000000',
      offsetX: 0,
      offsetY: 10
    })
    .onClick(() => {
      this.openNewNote(route.id);
    });
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Scroll() {
        Column({ space: 18 }) {
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

            Text('我的行记')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#14221D')
              .layoutWeight(1);
          }
          .width('100%');

          this.NewNoteCard();

          if (this.notes.length > 0) {
            Column({ space: 10 }) {
              Text('已保存的行记')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#24312E')
                .width('100%');

              ForEach(this.notes, (note: TravelNote) => {
                this.SavedNoteCard(note);
              }, (note: TravelNote) => note.id);
            }
            .width('100%');
          }

          if (this.routes.length === 0) {
            Column({ space: 10 }) {
              Text('还没有可写的路线')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#253238');

              Text('先去记录一条路线，或者直接点“新的行记”开始写。')
                .fontSize(14)
                .fontColor('#6B7280');
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#FFFFFF')
            .borderRadius(24);
          } else {
            Column({ space: 10 }) {
              Text('按路线开始写')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#24312E')
                .width('100%');

              ForEach(this.routes, (route: TravelRoute) => {
                this.RouteCard(route);
              }, (route: TravelRoute) => route.id);
            }
            .width('100%');
          }

          Blank()
            .height(88);
        }
        .width('100%')
        .padding({ top: 2, bottom: 16, left: 16, right: 16 });
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .onScroll((xOffset: number, yOffset: number) => {
        this.showFloatingCreate = yOffset > 120;
      });

      if (this.showFloatingCreate) {
        Button() {
          Text('+')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF');
        }
        .width(60)
        .height(60)
        .margin({ right: 20, bottom: 28 })
        .backgroundColor('#0F766E')
        .borderRadius(30)
        .shadow({
          radius: 22,
          color: '#33000000',
          offsetX: 0,
          offsetY: 10
        })
        .onClick(() => {
          this.openNewNote();
        });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F3EE');
  }
}
