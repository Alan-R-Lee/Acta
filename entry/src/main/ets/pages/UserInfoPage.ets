import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { PreferenceService } from '../common/service/PreferenceService';
import { AuthService } from '../common/service/AuthService';
import { MediaAssetService } from '../common/service/MediaAssetService';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct UserInfoPage {
  @State username: string = '';
  @State accountStatus: string = '云端账户';
  @State avatar: string = '';
  @State message: string = '';

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    try {
      await PreferenceService.init(this.context);
      this.username = await PreferenceService.getCurrentUsername();
      this.avatar = await PreferenceService.getCurrentAvatar();
    } catch (error) {
      this.username = '';
      this.avatar = '';
    }
  }

  private async changeAvatar(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      const selectedAvatar = Array.isArray(result.photoUris) && result.photoUris.length > 0 ? result.photoUris[0] : '';
      const nextAvatar = selectedAvatar
        ? await MediaAssetService.persistPickedImage(this.context, selectedAvatar, 'avatar')
        : '';
      if (!nextAvatar) {
        return;
      }

      this.avatar = nextAvatar;
      const updateResult = await AuthService.updateProfile(this.username, nextAvatar);
      this.message = updateResult.success ? '头像已更新并同步' : '头像已选择，但同步失败';
      if (!updateResult.success) {
        await PreferenceService.setCurrentAvatar(nextAvatar);
      }
    } catch (error) {
      this.message = '选择头像失败，请重试';
      console.error('Failed to change avatar.');
    }
  }

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from UserInfoPage.');
    }
  }

  @Builder
  private AvatarView() {
    if (this.avatar.length > 0) {
      Image(this.avatar)
        .width(108)
        .height(108)
        .objectFit(ImageFit.Cover)
        .borderRadius(54);
    } else {
      Text(this.username && this.username.length > 0 ? this.username.substring(0, 1).toUpperCase() : 'A')
        .fontSize(42)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .width(108)
        .height(108)
        .textAlign(TextAlign.Center)
        .backgroundColor('#0A84FF')
        .borderRadius(54);
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
        Stack({ alignContent: Alignment.BottomEnd }) {
          this.AvatarView();

          Button('更换')
            .fontSize(12)
            .height(30)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#111827')
            .fontColor('#FFFFFF')
            .borderRadius(15)
            .onClick(() => {
              void this.changeAvatar();
            });
        }
        .onClick(() => {
          void this.changeAvatar();
        });

        Text(this.username && this.username.length > 0 ? this.username : 'Acta 用户')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937');

        Text(this.accountStatus)
          .fontSize(14)
          .fontColor('#6B7280');

        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(13)
            .fontColor('#0F766E');
        }
      }
      .width('100%')
      .padding({ top: 26, bottom: 24 })
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
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')
      .borderRadius(16);
    }
    .padding(16)
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3');
  }
}
