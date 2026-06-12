import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { PreferenceService } from '../common/service/PreferenceService';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct UserInfoPage {
  @State username: string = '';
  @State accountStatus: string = '本地账户';

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    try {
      await PreferenceService.init(this.context);
      this.username = await PreferenceService.getCurrentUsername();
    } catch (error) {
      this.username = '';
    }
  }

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from UserInfoPage.');
    }
  }

  build() {
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

        Text('用户信息')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
          .layoutWeight(1);
      }
      .width('100%');

      Column({ space: 12 }) {
        Text(this.username && this.username.length > 0 ? this.username.substring(0, 1).toUpperCase() : 'A')
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width(108)
          .height(108)
          .textAlign(TextAlign.Center)
          .backgroundColor('#0A84FF')
          .borderRadius(54);

        Text(this.username && this.username.length > 0 ? this.username : 'Acta 用户')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937');

        Text(this.accountStatus)
          .fontSize(14)
          .fontColor('#6B7280');
      }
      .width('100%')
      .padding({
        top: 26,
        bottom: 24
      })
      .backgroundColor('#F7F9FC')
      .borderRadius(16);

      Column({ space: 0 }) {
        Row() {
          Text('用户名')
            .fontSize(16)
            .fontColor('#6B7280')
            .layoutWeight(1);
          Text(this.username && this.username.length > 0 ? this.username : '未登录')
            .fontSize(16)
            .fontColor('#1F2937');
        }
        .height(54)
        .width('100%');

        Divider()
          .strokeWidth(1)
          .color('#EEF0F2');

        Row() {
          Text('账户类型')
            .fontSize(16)
            .fontColor('#6B7280')
            .layoutWeight(1);
          Text(this.accountStatus)
            .fontSize(16)
            .fontColor('#1F2937');
        }
        .height(54)
        .width('100%');
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16
      })
      .backgroundColor('#FFFFFF')
      .borderRadius(16);
    }
    .padding(16)
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3');
  }
}
