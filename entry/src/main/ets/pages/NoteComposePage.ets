import router from '@ohos.router';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import common from '@ohos.app.ability.common';
import RouteStore from '../common/service/RouteStore';
import { TravelRoute } from '../common/model/TravelRoute';
import { TravelNote } from '../common/model/TravelNote';
import { TravelMemory } from '../common/model/TravelMemory';
import { TravelDataService } from '../common/service/TravelDataService';
import { PreferenceService } from '../common/service/PreferenceService';
import AiClient from '../common/service/ai/AiClient';
import { MediaAssetService } from '../common/service/MediaAssetService';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

interface NoteDraft {
  routeId: string;
  title: string;
  content: string;
  imageList: string[];
}

interface NoteComposeParams {
  routeId?: string;
  noteId?: string;
}

@Entry
@Component
struct NoteComposePage {
  @State routeId: string = '';
  @State noteId: string = '';
  @State title: string = '';
  @State content: string = '';
  @State imageList: string[] = [];
  @State routes: TravelRoute[] = [];
  @State selectedRouteTitle: string = '';
  @State routeName: string = '';
  @State routeMessage: string = '';
  @State memories: TravelMemory[] = [];
  @State isEditingExisting: boolean = false;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private suppressDraftSave: boolean = false;

  async aboutToAppear(): Promise<void> {
    await TravelDataService.syncFromServer();
    const params = router.getParams() as NoteComposeParams | null | undefined;
    this.routeId = params?.routeId || '';
    this.noteId = params?.noteId || '';
    this.routes = [...RouteStore.getRoutes()];

    if (this.noteId) {
      this.loadExistingNote(this.noteId);
      return;
    }

    if (!this.routeId && this.routes.length > 0) {
      this.routeId = this.routes[0].id;
    }

    this.refreshRoutes();
    await this.restoreDraft();
  }

  aboutToDisappear(): void {
    void this.persistDraft();
  }

  private loadExistingNote(noteId: string): void {
    this.suppressDraftSave = true;
    const note = RouteStore.getNoteById(noteId);
    if (!note) {
      this.routeMessage = '未找到要编辑的行记';
      this.suppressDraftSave = false;
      return;
    }

    this.isEditingExisting = true;
    this.noteId = note.id;
    this.routeId = note.routeId;
    this.title = note.title;
    this.content = note.content;
    this.imageList = [...note.images];
    this.refreshRoutes();
    this.routeMessage = '正在编辑已保存的行记';
    this.suppressDraftSave = false;
  }

  private getDraftKeyRouteId(): string {
    return this.routeId || 'default';
  }

  private async restoreDraft(): Promise<void> {
    if (this.isEditingExisting) {
      return;
    }

    this.suppressDraftSave = true;
    try {
      const raw = await PreferenceService.getNoteDraft(this.getDraftKeyRouteId());
      if (!raw) {
        return;
      }

      const draft = JSON.parse(raw) as NoteDraft;
      this.routeId = draft.routeId || this.routeId;
      this.title = draft.title || '';
      this.content = draft.content || '';
      this.imageList = Array.isArray(draft.imageList) ? draft.imageList : [];
      this.refreshRoutes();
      if (this.title || this.content || this.imageList.length > 0) {
        this.routeMessage = '已恢复上次未完成的行记草稿';
      }
    } catch (error) {
      console.error('Failed to restore note draft.');
    } finally {
      this.suppressDraftSave = false;
    }
  }

  private async persistDraft(): Promise<void> {
    if (this.suppressDraftSave || this.isEditingExisting) {
      return;
    }

    const hasContent = this.title.trim().length > 0 || this.content.trim().length > 0 || this.imageList.length > 0;
    if (!hasContent) {
      await PreferenceService.removeNoteDraft(this.getDraftKeyRouteId());
      return;
    }

    const draft: NoteDraft = {
      routeId: this.routeId,
      title: this.title,
      content: this.content,
      imageList: [...this.imageList]
    };
    await PreferenceService.setNoteDraft(this.getDraftKeyRouteId(), JSON.stringify(draft));
  }

  private queueDraftSave(): void {
    void this.persistDraft();
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
      this.routeMessage = '请输入路线名称';
      return;
    }

    const route = new TravelRoute(`${Date.now()}`, name);
    RouteStore.addRoute(route);
    await TravelDataService.createRoute(route);
    this.routeId = route.id;
    this.routeName = '';
    this.routeMessage = '已新建并关联当前行记';
    this.refreshRoutes();
    this.queueDraftSave();
  }

  private selectRoute(routeId: string): void {
    if (this.isEditingExisting) {
      this.routeId = routeId;
      this.refreshRoutes();
      return;
    }

    this.routeId = routeId;
    this.routeMessage = '';
    this.refreshRoutes();
    void this.restoreDraft();
  }

  private async addImage(): Promise<void> {
    if (this.imageList.length >= 9) {
      return;
    }

    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = Math.max(1, 9 - this.imageList.length);

      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      const selectedUris = Array.isArray(result.photoUris) ? result.photoUris : [];
      if (selectedUris.length === 0) {
        return;
      }

      const nextImages = [...this.imageList];
      for (let i = 0; i < selectedUris.length; i++) {
        const persistedUri = await MediaAssetService.persistPickedImage(this.context, selectedUris[i], 'note');
        if (nextImages.indexOf(persistedUri) < 0 && nextImages.length < 9) {
          nextImages.push(persistedUri);
        }
      }
      this.imageList = nextImages;
      this.queueDraftSave();
    } catch (error) {
      this.routeMessage = '选择图片失败，请重试';
      console.error('Failed to select note images.');
    }
  }

  private removeImage(index: number): void {
    this.imageList = this.imageList.filter((item: string, itemIndex: number) => itemIndex !== index);
    this.queueDraftSave();
  }

  private async generateNoteFromMemories(): Promise<void> {
    if (this.memories.length === 0) {
      this.routeMessage = '当前路线还没有可汇总的记忆点';
      return;
    }

    const memoryLines: string[] = [];
    for (let i = 0; i < this.memories.length; i++) {
      const memory = this.memories[i];
      memoryLines.push(
        `${i + 1}. ${memory.title}（${memory.lat.toFixed(5)}, ${memory.lng.toFixed(5)}）：${memory.content || '这里还没有文字记录。'}`
      );
    }

    this.routeMessage = '正在生成 AI 行记草稿...';

    const prompt = `请基于以下旅行路线与记忆点，生成一篇适合发布的中文行记草稿。路线标题：${this.selectedRouteTitle}。记忆点如下：\n${memoryLines.join('\n')}\n\n要求：输出自然流畅，分成2到4段，可以补充节奏、风景、情绪和建议标题。`;

    try {
      const aiContent = await AiClient.generateText(prompt);
      this.title = this.title || `${this.selectedRouteTitle} 行记`;
      this.content = aiContent && aiContent.length > 0
        ? aiContent
        : `AI行记草稿：\n本次路线围绕 ${this.selectedRouteTitle} 展开，途中记录了 ${this.memories.length} 个记忆点。\n\n${memoryLines.join('\n')}\n\n可以继续补充天气、同行人、心情和路线亮点。`;
      this.routeMessage = '已根据记忆点生成行记草稿';
    } catch (error) {
      this.title = this.title || `${this.selectedRouteTitle} 行记`;
      this.content = `AI行记草稿：\n本次路线围绕 ${this.selectedRouteTitle} 展开，途中记录了 ${this.memories.length} 个记忆点。\n\n${memoryLines.join('\n')}\n\n可以继续补充天气、同行人、心情和路线亮点。`;
      this.routeMessage = 'AI 生成失败，已回退到本地草稿';
    }
    this.queueDraftSave();
  }

  private async saveNote(): Promise<void> {
    if (!this.routeId) {
      const route = new TravelRoute(`${Date.now()}`, this.title || '未命名路线');
      RouteStore.addRoute(route);
      await TravelDataService.createRoute(route);
      this.routeId = route.id;
      this.refreshRoutes();
    }

    if (this.isEditingExisting && this.noteId) {
      const existing = RouteStore.getNoteById(this.noteId);
      const note = existing || new TravelNote(this.noteId, this.routeId, '', '');
      note.routeId = this.routeId;
      note.title = this.title || '未命名行记';
      note.content = this.content;
      note.images = [...this.imageList];
      RouteStore.updateNote(note);
      await TravelDataService.updateNote(note);
      this.goHome();
      return;
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
    await PreferenceService.removeNoteDraft(this.getDraftKeyRouteId());
    this.title = '';
    this.content = '';
    this.imageList = [];
    this.goHome();
  }

  private goBack(): void {
    try {
      this.goHome();
    } catch (error) {
      console.error('Failed to navigate back from NoteComposePage.');
    }
  }

  private goHome(): void {
    router.replaceUrl({
      url: 'pages/HomePage'
    });
  }

  @Builder
  private RouteSelector() {
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
          .enabled(!this.isEditingExisting)
          .onChange((value: string) => {
            this.routeName = value;
          });

        Button('新建')
          .height(42)
          .enabled(!this.isEditingExisting)
          .onClick(() => {
            void this.createRoute();
          });
      }
      .width('100%');

      if (this.routeMessage.length > 0) {
        Text(this.routeMessage)
          .fontSize(12)
          .fontColor(this.routeMessage === '请输入路线名称' ? '#D9485F' : '#2BA471')
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
  }

  @Builder
  private MemorySummaryPanel() {
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
            void this.generateNoteFromMemories();
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
  }

  @Builder
  private ImagePickerPanel() {
    Button('添加图片')
      .width('100%')
      .enabled(this.imageList.length < 9)
      .onClick(() => {
        void this.addImage();
      });

    Text(`已添加图片：${this.imageList.length}/9`)
      .fontSize(14);

    if (this.imageList.length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.imageList, (item: string, index: number) => {
          Stack({ alignContent: Alignment.TopEnd }) {
            Image(item)
              .width(92)
              .height(92)
              .objectFit(ImageFit.Cover)
              .borderRadius(8);

            Button('×')
              .width(28)
              .height(28)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#99000000')
              .borderRadius(14)
              .onClick(() => {
                this.removeImage(index);
              });
          }
          .width(92)
          .height(92)
          .margin({
            right: 8,
            bottom: 8
          });
        }, (item: string) => item);
      }
      .width('100%');
    }
  }

  build() {
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

          Text(this.isEditingExisting ? '编辑行记' : '行记写作')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1);
        }
        .width('100%');

        Text(`关联路线：${this.selectedRouteTitle}`)
          .fontSize(14)
          .fontColor('#666666');

        this.RouteSelector();
        this.MemorySummaryPanel();

        Text('标题')
          .fontSize(15)
          .fontWeight(FontWeight.Medium);

        TextInput({
          placeholder: '输入行记标题',
          text: this.title
        })
          .onChange((value: string) => {
            this.title = value;
            this.queueDraftSave();
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
            this.queueDraftSave();
          });

        this.ImagePickerPanel();

        Button(this.isEditingExisting ? '保存修改' : '保存行记')
          .width('100%')
          .onClick(() => {
            void this.saveNote();
          });
      }
      .padding({ top: 12, bottom: 16, left: 16, right: 16 })
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Auto);
  }
}
