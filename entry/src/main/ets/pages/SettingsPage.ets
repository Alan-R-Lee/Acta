import router from '@ohos.router';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

@Entry
@Component
struct SettingsPage {
  @State locationPreviewEnabled: boolean = true;
  @State aiAssistEnabled: boolean = true;
  @State compactListEnabled: boolean = false;

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from SettingsPage.');
    }
  }

  @Builder
  private SettingRow(title: string, description: string, enabled: boolean, onChange: (value: boolean) => void) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(17)
          .fontColor('#1F2937')
          .fontWeight(FontWeight.Medium);

        Text(description)
          .fontSize(13)
          .fontColor('#6B7280')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1);

      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .onChange((isOn: boolean) => {
          onChange(isOn);
        });
    }
    .width('100%')
    .padding({
      top: 14,
      bottom: 14
    });
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

        Text('设置')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
          .layoutWeight(1);
      }
      .width('100%');

      Column({ space: 0 }) {
        this.SettingRow('定位预览', '主页面无路线时自动展示当前位置', this.locationPreviewEnabled, (value: boolean) => {
          this.locationPreviewEnabled = value;
        });

        Divider()
          .strokeWidth(1)
          .color('#EEF0F2');

        this.SettingRow('AI 辅助', '保留行程分析和帮助问答入口', this.aiAssistEnabled, (value: boolean) => {
          this.aiAssistEnabled = value;
        });

        Divider()
          .strokeWidth(1)
          .color('#EEF0F2');

        this.SettingRow('紧凑列表', '减少保存路线列表的垂直间距', this.compactListEnabled, (value: boolean) => {
          this.compactListEnabled = value;
        });
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
