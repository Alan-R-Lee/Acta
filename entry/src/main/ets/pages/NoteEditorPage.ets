import router from '@ohos.router';
import RouteStore from '../common/service/RouteStore';
import { TravelRoute } from '../common/model/TravelRoute';
import { TravelNote } from '../common/model/TravelNote';

@Entry
@Component
struct NoteEditorPage {
  @State routeId: string = '';
  @State title: string = '';
  @State content: string = '';
  @State imageList: string[] = [];
  @State routes: TravelRoute[] = [];
  @State selectedRouteTitle: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.routeId = params['routeId'] || '';
    this.routes = [...RouteStore.getRoutes()];

    if (!this.routeId && this.routes.length > 0) {
      this.routeId = this.routes[0].id;
    }

    const route = RouteStore.getRouteById(this.routeId);
    this.selectedRouteTitle = route ? route.title : '未关联路线';
  }

  private addMockImage(): void {
    this.imageList = [...this.imageList, `/mock/image_${Date.now()}.png`];
  }

  private saveNote(): void {
    const note = new TravelNote(
      `${Date.now()}`,
      this.routeId,
      this.title || '未命名行记',
      this.content
    );
    note.images = [...this.imageList];
    RouteStore.addNote(note);
    router.back();
  }

  build() {
    Column({ space: 12 }) {
      Text('行记写作')
        .fontSize(26)
        .fontWeight(FontWeight.Bold);

      Text(`关联路线：${this.selectedRouteTitle}`)
        .fontSize(14)
        .fontColor('#666666');

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
          this.saveNote();
        });
    }
    .padding(16)
    .width('100%')
    .height('100%');
  }
}