import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { BackChevronIcon } from '../common/component/BackChevronIcon';
import { AuthResult, AuthService } from '../common/service/AuthService';
import { PreferenceService } from '../common/service/PreferenceService';

@Entry
@Component
struct AuthPage {
  @State isLoginMode: boolean = false;
  @State isSubmitting: boolean = false;

  @State username: string = '';
  @State displayName: string = '';
  @State email: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';

  @State message: string = '';
  @State messageColor: string = '#D9485F';

  private context = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.initPage();
  }

  private async initPage(): Promise<void> {
    try {
      await PreferenceService.init(this.context);
      await PreferenceService.ensureDefaults();
      const isFirstLaunch = await PreferenceService.isFirstLaunch();
      this.isLoginMode = !isFirstLaunch;
    } catch (error) {
      console.error('AuthPage init failed.');
    }
  }

  private showError(msg: string): void {
    this.message = msg;
    this.messageColor = '#D9485F';
  }

  private showSuccess(msg: string): void {
    this.message = msg;
    this.messageColor = '#2BA471';
  }

  private isPasswordValid(password: string): boolean {
    if (password.length < 8) {
      return false;
    }

    let hasLetter = false;
    let hasDigit = false;
    for (let i = 0; i < password.length; i++) {
      const ch = password.charAt(i);
      if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
        hasLetter = true;
      }
      if (ch >= '0' && ch <= '9') {
        hasDigit = true;
      }
    }

    return hasLetter && hasDigit;
  }

  private isEmailValid(email: string): boolean {
    if (email.length === 0) {
      return true;
    }

    return email.indexOf('@') > 0 && email.indexOf('.') > email.indexOf('@') + 1;
  }

  private validateInput(): boolean {
    const username = this.username.trim();
    const email = this.email.trim();

    if (username.length < 3) {
      this.showError('用户名至少 3 位。');
      return false;
    }

    if (!this.isLoginMode && !this.isEmailValid(email)) {
      this.showError('请输入有效的邮箱地址，或留空。');
      return false;
    }

    if (this.isLoginMode && this.password.length === 0) {
      this.showError('请输入密码。');
      return false;
    }

    if (!this.isLoginMode && !this.isPasswordValid(this.password)) {
      this.showError('密码至少 8 位，且必须包含字母和数字。');
      return false;
    }

    if (!this.isLoginMode && this.password !== this.confirmPassword) {
      this.showError('两次输入的密码不一致。');
      return false;
    }

    return true;
  }

  private getResultMessage(result: AuthResult): string {
    if (result.success) {
      if (result.source === 'local') {
        return this.isLoginMode
          ? '服务器暂不可用，已使用本地账号登录。'
          : '服务器暂不可用，已注册为本地账号。';
      }

      return this.isLoginMode ? '登录成功，正在进入主页...' : '注册成功，正在进入主页...';
    }

    if (result.message === 'Username already exists.') {
      return '用户名已存在，请更换。';
    }

    if (result.message === 'Username or password is incorrect.') {
      return '用户名或密码错误。';
    }

    if (result.message === 'AUTH_SERVER_UNREACHABLE') {
      return '无法连接登录服务器，请检查服务器地址或网络。';
    }

    return result.message;
  }

  private async submit(): Promise<void> {
    if (this.isSubmitting || !this.validateInput()) {
      return;
    }

    this.isSubmitting = true;
    this.message = '';

    const username = this.username.trim();
    const email = this.email.trim();
    const displayName = this.displayName.trim();
    let result: AuthResult;

    if (this.isLoginMode) {
      result = await AuthService.login(username, this.password);
    } else {
      result = await AuthService.register(username, this.password, email, displayName);
    }

    this.isSubmitting = false;
    const message = this.getResultMessage(result);
    if (!result.success) {
      this.showError(message);
      return;
    }

    this.showSuccess(message);
    setTimeout(() => {
      this.goHome();
    }, 800);
  }

  private goHome(): void {
    try {
      router.replaceUrl({
        url: 'pages/HomePage'
      });
    } catch (error) {
      console.error('Failed to navigate to HomePage.');
    }
  }

  private goBack(): void {
    try {
      router.back();
    } catch (error) {
      console.error('Failed to navigate back from AuthPage.');
    }
  }

  build() {
    Column({ space: 16 }) {
      Row() {
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

        Blank()
          .layoutWeight(1);
      }
      .width('100%')
      .height(44);

      Text('Acta')
        .fontSize(30)
        .fontWeight(FontWeight.Bold);

      Text(this.isLoginMode ? '欢迎回来，请登录' : '欢迎使用 Acta，请先注册')
        .fontSize(14)
        .fontColor('#666666');

      Row({ space: 8 }) {
        Button('登录')
          .layoutWeight(1)
          .backgroundColor(this.isLoginMode ? '#4A7BFF' : '#DDE6FF')
          .fontColor(this.isLoginMode ? '#FFFFFF' : '#2F4B8F')
          .onClick(() => {
            this.isLoginMode = true;
            this.message = '';
          });

        Button('注册')
          .layoutWeight(1)
          .backgroundColor(!this.isLoginMode ? '#4A7BFF' : '#DDE6FF')
          .fontColor(!this.isLoginMode ? '#FFFFFF' : '#2F4B8F')
          .onClick(() => {
            this.isLoginMode = false;
            this.message = '';
          });
      }
      .margin({ top: 10, bottom: 10 });

      Column({ space: 12 }) {
        TextInput({
          placeholder: '用户名（至少 3 位）',
          text: this.username
        })
        .onChange((value: string) => {
          this.username = value;
        });

        if (!this.isLoginMode) {
          TextInput({
            placeholder: '昵称（可选，用于个人资料）',
            text: this.displayName
          })
          .onChange((value: string) => {
            this.displayName = value;
          });

          TextInput({
            placeholder: '邮箱（可选，用于后续账号找回）',
            text: this.email
          })
          .onChange((value: string) => {
            this.email = value;
          });
        }

        TextInput({
          placeholder: '密码（至少 8 位，包含字母和数字）',
          text: this.password
        })
        .type(InputType.Password)
        .onChange((value: string) => {
          this.password = value;
        });

        if (!this.isLoginMode) {
          TextInput({
            placeholder: '确认密码',
            text: this.confirmPassword
          })
          .type(InputType.Password)
          .onChange((value: string) => {
            this.confirmPassword = value;
          });
        }
      }
      .margin({ top: 8 });

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor(this.messageColor);
      }

      Button(this.isSubmitting ? '处理中...' : (this.isLoginMode ? '立即登录' : '立即注册'))
        .width('100%')
        .height(46)
        .margin({ top: 12 })
        .enabled(!this.isSubmitting)
        .onClick(async () => {
          await this.submit();
        });

      if (!this.isLoginMode) {
        Text('密码规则：至少 8 位，必须同时包含字母和数字。')
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 6 });
      }

      Blank()
        .layoutWeight(1);
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }
}
