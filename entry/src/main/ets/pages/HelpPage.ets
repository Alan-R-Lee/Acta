import router from '@ohos.router';
import AiClient from '../common/service/ai/AiClient';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct HelpPage {
  @State question: string = '';
  @State answer: string = '可以在这里直接向 AI 询问路线记录、定位权限、行记编辑等问题。';
  @State isAsking: boolean = false;

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from HelpPage.');
    }
  }

  private async askAiHelp(): Promise<void> {
    const cleanQuestion = this.question.trim();
    if (cleanQuestion.length === 0) {
      this.answer = '请输入你想咨询的问题。';
      return;
    }

    this.isAsking = true;
    this.answer = 'AI 正在思考...';
    try {
      const prompt = `你是 Acta 旅行记录应用的帮助助手。请用简洁中文回答用户问题：${cleanQuestion}`;
      const result = await AiClient.generateText(prompt);
      this.answer = result && result.length > 0 ? result : 'AI 没有返回可用答案。';
    } catch (error) {
      this.answer = 'AI 帮助请求失败，请稍后再试。';
    } finally {
      this.isAsking = false;
    }
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
        Text('AI 帮助问答')
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
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.question = value;
          });

        Button(this.isAsking ? '询问中...' : '询问 AI')
          .width('100%')
          .height(44)
          .enabled(!this.isAsking)
          .borderRadius(22)
          .onClick(() => {
            void this.askAiHelp();
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
