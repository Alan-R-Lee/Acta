import router from '@ohos.router';
import { PreferenceService } from '../common/service/PreferenceService';
import { User } from '../common/model/User';
import common from '@ohos.app.ability.common';
import { BackChevronIcon } from '../common/component/BackChevronIcon';

interface UserPlainObject {
  id: number;
  username: string;
  passwordHash: string;
  createdAt: number;
}

@Entry
@Component
struct AuthPage {
  @State isLoginMode: boolean = false;

  @State username: string = '';
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
      this.isLoginMode = !isFirstLaunch ? true : false;
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

    let hasLetter: boolean = false;
    let hasDigit: boolean = false;

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

  private simpleHash(text: string): string {
    let hash: number = 0;
    for (let i = 0; i < text.length; i++) {
      hash = ((hash << 5) - hash) + text.charCodeAt(i);
      hash |= 0;
    }
    return `${hash}`;
  }

  private async loadUsers(): Promise<User[]> {
    const jsonText: string = await PreferenceService.getUsersJson();
    if (!jsonText || jsonText.trim() === '') {
      return [];
    }

    try {
      const arr = JSON.parse(jsonText) as UserPlainObject[];
      const users: User[] = [];
      for (let i = 0; i < arr.length; i++) {
        const item = arr[i];
        users.push(new User(item.id, item.username, item.passwordHash, item.createdAt));
      }
      return users;
    } catch (error) {
      return [];
    }
  }

  private async saveUsers(users: User[]): Promise<void> {
    await PreferenceService.setUsersJson(JSON.stringify(users));
  }

  private async register(): Promise<void> {
    const username = this.username.trim();
    const password = this.password;
    const confirmPassword = this.confirmPassword;

    if (username.length < 3) {
      this.showError('用户名至少 3 位。');
      return;
    }

    if (!this.isPasswordValid(password)) {
      this.showError('密码至少 8 位，且必须包含字母和数字。');
      return;
    }

    if (password !== confirmPassword) {
      this.showError('两次输入的密码不一致。');
      return;
    }

    const users = await this.loadUsers();
    const exists = users.some((item: User) => item.username === username);
    if (exists) {
      this.showError('用户名已存在，请更换。');
      return;
    }

    const nextId: number = users.length > 0 ? users[0].id + 1 : 1;
    const user = new User(nextId, username, this.simpleHash(password), Date.now());
    users.unshift(user);

    await this.saveUsers(users);
    await PreferenceService.setFirstLaunch(false);
    await PreferenceService.setLoggedIn(true);
    await PreferenceService.setCurrentUserId(user.id);
    await PreferenceService.setCurrentUsername(user.username);

    this.showSuccess('注册成功，正在进入主页...');
    setTimeout(() => {
      this.goHome();
    }, 800);
  }

  private async login(): Promise<void> {
    const username = this.username.trim();
    const password = this.password;

    if (username.length === 0 || password.length === 0) {
      this.showError('请输入用户名和密码。');
      return;
    }

    const users = await this.loadUsers();
    const passwordHash: string = this.simpleHash(password);

    const user = users.find((item: User) => {
      return item.username === username && item.passwordHash === passwordHash;
    });

    if (!user) {
      this.showError('用户名或密码错误。');
      return;
    }

    await PreferenceService.setFirstLaunch(false);
    await PreferenceService.setLoggedIn(true);
    await PreferenceService.setCurrentUserId(user.id);
    await PreferenceService.setCurrentUsername(user.username);

    this.showSuccess('登录成功，正在进入主页...');
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

      Button(this.isLoginMode ? '立即登录' : '立即注册')
        .width('100%')
        .height(46)
        .margin({ top: 12 })
        .onClick(async () => {
          if (this.isLoginMode) {
            await this.login();
          } else {
            await this.register();
          }
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
