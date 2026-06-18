import router from '@ohos.router';
import RouteStore from '../common/service/RouteStore';
import { TravelMemory } from '../common/model/TravelMemory';
import { TravelDataService } from '../common/service/TravelDataService';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct MemoryEditorPage {
  @State routeId: string = '';
  @State pointTime: number = 0;
  @State lat: number = 0;
  @State lng: number = 0;
  @State altitude: number = 0;
  @State title: string = '';
  @State content: string = '';
  @State imageList: string[] = [];
  @State message: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string | number> | null | undefined;
    this.routeId = `${params?.['routeId'] || ''}`;
    this.pointTime = Number(params?.['pointTime'] || Date.now());
    this.lat = Number(params?.['lat'] || 0);
    this.lng = Number(params?.['lng'] || 0);
    this.altitude = Number(params?.['altitude'] || 0);
  }

  private addImage(): void {
    this.imageList = [...this.imageList, `/memory/image_${Date.now()}.png`];
  }

  private async saveMemory(): Promise<boolean> {
    if (!this.routeId) {
      this.message = '缺少路线信息，无法保存记忆';
      return false;
    }

    const memory = new TravelMemory(
      `${Date.now()}`,
      this.routeId,
      this.pointTime,
      this.lat,
      this.lng,
      this.altitude,
      this.title || '未命名记忆',
      this.content
    );
    memory.images = [...this.imageList];
    RouteStore.addMemory(memory);
    await TravelDataService.createMemory(memory);
    this.message = '记忆已保存';
    return true;
  }

  private async saveAndBack(): Promise<void> {
    if (await this.saveMemory()) {
      router.back();
    }
  }

  private async saveAndOpenNote(): Promise<void> {
    if (!await this.saveMemory()) {
      return;
    }

    try {
      router.pushUrl({
        url: 'pages/NoteEditorPage',
        params: {
          routeId: this.routeId
        }
      });
    } catch (error) {
      console.error('Failed to navigate to NoteEditorPage from MemoryEditorPage.');
    }
  }

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from MemoryEditorPage.');
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

        Text('旅行记忆')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1);
      }
      .width('100%');

      Column({ space: 4 }) {
        Text(`纬度 ${this.lat.toFixed(5)}  经度 ${this.lng.toFixed(5)}`)
          .fontSize(14)
          .fontColor('#1F2937');
        Text(`海拔 ${this.altitude.toFixed(0)} m`)
          .fontSize(13)
          .fontColor('#6B7280');
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F4F7FB')
      .borderRadius(12);

      Text('标题')
        .fontSize(15)
        .fontWeight(FontWeight.Medium);

      TextInput({
        placeholder: '给这个记忆点起个名字',
        text: this.title
      })
        .onChange((value: string) => {
          this.title = value;
        });

      Text('行记内容')
        .fontSize(15)
        .fontWeight(FontWeight.Medium);

      TextArea({
        placeholder: '记录这里发生的事、看到的风景和你的感受',
        text: this.content
      })
        .height(220)
        .onChange((value: string) => {
          this.content = value;
        });

      Button('添加图片（Demo占位）')
        .width('100%')
        .onClick(() => {
          this.addImage();
        });

      Text(`已添加图片：${this.imageList.length}`)
        .fontSize(14)
        .fontColor('#4B5563');

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
        .height(110);
      }

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor(this.message === '记忆已保存' ? '#16A34A' : '#D9485F');
      }

      Row({ space: 8 }) {
        Button('保存记忆')
          .layoutWeight(1)
          .onClick(() => {
            void this.saveAndBack();
          });

        Button('去行记页汇总')
          .layoutWeight(1)
          .onClick(() => {
            void this.saveAndOpenNote();
          });
      }
      .width('100%');
    }
    .padding(16)
    .width('100%')
    .height('100%');
  }
}
