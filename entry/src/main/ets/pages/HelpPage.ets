import router from '@ohos.router';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct HelpPage {
  @State question: string = '';
  @State answer: string = '可以在这里接入 AI 帮助接口，回答路线记录、定位权限、行记编辑等问题。';

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from HelpPage.');
    }
  }

  private askAiHelp(): void {
    const cleanQuestion = this.question.trim();
    if (cleanQuestion.length === 0) {
      this.answer = '请输入你想咨询的问题。';
      return;
    }

    this.answer = `AI 帮助接口预留：收到问题“${cleanQuestion}”。后续可在这里接入云端大模型或本地帮助知识库。`;
  }

  build() {
    Column({ space: 16 }) {
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

        Text('帮助')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
          .layoutWeight(1);
      }
      .width('100%');

      Column({ space: 10 }) {
        Text('常见问题')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .width('100%');

        Text('路线记录需要定位权限；首页地图会在无路线时显示当前位置，有路线时显示最新保存路线。')
          .fontSize(14)
          .fontColor('#4B5563')
          .width('100%');
      }
      .padding(16)
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(16);

      Column({ space: 12 }) {
        Text('AI 帮助接口')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .width('100%');

        TextInput({
          placeholder: '输入你遇到的问题',
          text: this.question
        })
          .height(48)
          .backgroundColor('#F3F4F6')
          .borderRadius(12)
          .padding({
            left: 12,
            right: 12
          })
          .onChange((value: string) => {
            this.question = value;
          });

        Button('询问 AI')
          .width('100%')
          .height(44)
          .borderRadius(22)
          .onClick(() => {
            this.askAiHelp();
          });

        Text(this.answer)
          .fontSize(14)
          .fontColor('#4B5563')
          .width('100%')
          .padding(12)
          .backgroundColor('#F7F9FC')
          .borderRadius(12);
      }
      .padding(16)
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(16);
    }
    .padding(16)
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3');
  }
}
