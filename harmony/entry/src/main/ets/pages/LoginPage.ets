import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { HttpClient } from '../api/HttpClient';
import { AuthPasswordBody } from '../api/ApiPayloads';

/** 设计稿主色 */
const PRIMARY_BLUE: string = '#166DE0';
const INPUT_BG: string = '#F5F5F5';
const TEXT_MUTED: string = '#999999';
const LOGIN_GRADIENT_START: string = '#E8F4FD';
const LOGIN_GRADIENT_END: string = '#E8F5E9';
const REGISTER_PAGE_BG: string = '#EEF2F6';

interface AuthTokensData {
  access_token: string;
  refresh_token: string;
  user_id: string;
}

interface AuthPostEnvelope {
  data?: AuthTokensData;
}

@Entry
@Component
struct LoginPage {
  @State phone: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State tab: number = 0;
  @State error: string = '';
  @State loading: boolean = false;
  @State showPwdRegister: boolean = false;
  @State showPwdConfirm: boolean = false;

  async persistSession(data: AuthTokensData): Promise<void> {
    const store = await preferences.getPreferences(getContext(this), 'auth');
    await store.put('token', data.access_token);
    await store.put('refresh_token', data.refresh_token);
    await store.put('user_id', data.user_id);
    await store.put('phone', this.phone);
    await store.flush();
    HttpClient.setContext(getContext(this));
    HttpClient.setSession(data.access_token, data.refresh_token);
    router.replaceUrl({ url: 'pages/MapPage' });
  }

  validateLogin(): boolean {
    if (this.phone.replace(/\s/g, '').length < 11) {
      this.error = '请输入正确的手机号';
      return false;
    }
    if (this.password.length === 0) {
      this.error = '请输入密码';
      return false;
    }
    return true;
  }

  validateRegister(): boolean {
    const p = this.phone.replace(/\s/g, '');
    if (p.length !== 11 || !/^\d{11}$/.test(p)) {
      this.error = '请输入11位手机号码';
      return false;
    }
    if (!/^[a-zA-Z0-9]{6,16}$/.test(this.password)) {
      this.error = '密码需为6-16位字母与数字组合';
      return false;
    }
    if (this.password !== this.confirmPassword) {
      this.error = '两次输入的密码不一致';
      return false;
    }
    return true;
  }

  async submit(): Promise<void> {
    this.error = '';
    if (this.tab === 0) {
      if (!this.validateLogin()) {
        return;
      }
    } else {
      if (!this.validateRegister()) {
        return;
      }
    }
    this.loading = true;
    const path = this.tab === 0 ? '/auth/login' : '/auth/register';
    try {
      const body: AuthPasswordBody = { phone: this.phone.replace(/\s/g, ''), password: this.password };
      const res = await HttpClient.post(path, body) as AuthPostEnvelope;
      const data = res.data;
      if (!data || !data.access_token) {
        this.error = this.tab === 0 ? '登录失败' : '注册失败';
        return;
      }
      await this.persistSession(data);
    } catch {
      this.error = this.tab === 0 ? '登录失败' : '注册失败';
    } finally {
      this.loading = false;
    }
  }

  onOtherLoginTap(): void {
    promptAction.showToast({ message: '其他登录方式即将上线' });
  }

  build() {
    Column() {
      if (this.tab === 0) {
        this.LoginBody();
      } else {
        this.RegisterBody();
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: this.tab === 0 ?
        [[LOGIN_GRADIENT_START, 0.0], [LOGIN_GRADIENT_END, 1.0]] :
        [[REGISTER_PAGE_BG, 0.0], [REGISTER_PAGE_BG, 1.0]]
    })
  }

  @Builder
  LoginBody() {
    Scroll() {
      Column() {
        Column() {
          Image($r('app.media.app_icon'))
            .width(72)
            .height(72)
            .borderRadius(18)
            .margin({ bottom: 12 })
          Text('定位共享')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_BLUE)
          Text('THE GUARDIAN LINK')
            .fontSize(11)
            .fontColor(TEXT_MUTED)
            .letterSpacing(1.2)
            .margin({ top: 6 })
        }
        .width('100%')
        .padding({ top: 28, bottom: 20 })

        Column() {
          Text('欢迎回来')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .width('100%')
            .margin({ bottom: 20 })

          Text('手机号')
            .fontSize(13)
            .fontColor(TEXT_MUTED)
            .width('100%')
            .margin({ bottom: 8 })
          Row() {
            Text('📱')
              .fontSize(18)
              .margin({ left: 14, right: 8 })
            TextInput({ placeholder: '输入您的手机号码', text: this.phone })
              .type(InputType.PhoneNumber)
              .maxLength(11)
              .placeholderColor(TEXT_MUTED)
              .fontColor('#111111')
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onChange((val: string) => {
                this.phone = val;
              })
          }
          .width('100%')
          .height(52)
          .backgroundColor(INPUT_BG)
          .borderRadius(14)
          .margin({ bottom: 18 })

          Text('密码')
            .fontSize(13)
            .fontColor(TEXT_MUTED)
            .width('100%')
            .margin({ bottom: 8 })

          Row() {
            Text('🔒')
              .fontSize(18)
              .margin({ left: 14, right: 8 })
            TextInput({ placeholder: '输入您的登录密码', text: this.password })
              .type(InputType.Password)
              .placeholderColor(TEXT_MUTED)
              .fontColor('#111111')
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onChange((val: string) => {
                this.password = val;
              })
          }
          .width('100%')
          .height(52)
          .backgroundColor(INPUT_BG)
          .borderRadius(14)
          .margin({ bottom: 20 })

          if (this.error.length > 0) {
            Text(this.error)
              .fontColor('#E53935')
              .fontSize(13)
              .width('100%')
              .margin({ bottom: 12 })
          }

          Button() {
            Row() {
              Text(this.loading ? '登录中...' : '登录')
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
              Text(' →')
                .fontSize(17)
                .fontColor(Color.White)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
          }
          .width('100%')
          .height(52)
          .backgroundColor(PRIMARY_BLUE)
          .borderRadius(16)
          .enabled(!this.loading)
          .onClick(() => {
            void this.submit();
          })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 26, bottom: 22 })
        .backgroundColor(Color.White)
        .borderRadius(28)
        .shadow({ radius: 24, color: '#00000012', offsetY: 8 })

        Row() {
          Text('还没有账号？')
            .fontSize(14)
            .fontColor(TEXT_MUTED)
          Text('去注册')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_BLUE)
            .onClick(() => {
              this.tab = 1;
              this.error = '';
              this.confirmPassword = '';
            })
        }
        .margin({ top: 24 })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  RegisterBody() {
    Scroll() {
      Column() {
        Row() {
          Text('🛡')
            .fontSize(16)
            .margin({ right: 6 })
          Text('定位共享')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_BLUE)
        }
        .width('100%')
        .padding({ top: 16, bottom: 8 })

        Column() {
          Text('👤')
            .fontSize(28)
            .width(56)
            .height(56)
            .textAlign(TextAlign.Center)
            .borderRadius(14)
            .backgroundColor('#E3F2FD')
            .margin({ bottom: 16 })
          Text('注册新账号')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
          Text('开启您的守护之旅，共享安心每一刻')
            .fontSize(13)
            .fontColor(TEXT_MUTED)
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 8, right: 8, bottom: 16 })

        Column() {
          Text('手机号')
            .fontSize(13)
            .fontColor(TEXT_MUTED)
            .width('100%')
            .margin({ bottom: 8 })
          Row() {
            Text('📱')
              .fontSize(18)
              .margin({ left: 14, right: 8 })
            TextInput({ placeholder: '请输入11位手机号码', text: this.phone })
              .type(InputType.PhoneNumber)
              .maxLength(11)
              .placeholderColor(TEXT_MUTED)
              .fontColor('#111111')
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onChange((val: string) => {
                this.phone = val;
              })
          }
          .width('100%')
          .height(52)
          .backgroundColor(INPUT_BG)
          .borderRadius(14)
          .margin({ bottom: 16 })

          Text('设置密码')
            .fontSize(13)
            .fontColor(TEXT_MUTED)
            .width('100%')
            .margin({ bottom: 8 })
          Row() {
            Text('🔒')
              .fontSize(18)
              .margin({ left: 14, right: 8 })
            TextInput({ placeholder: '6-16位字母与数字组合', text: this.password })
              .type(this.showPwdRegister ? InputType.Normal : InputType.Password)
              .placeholderColor(TEXT_MUTED)
              .fontColor('#111111')
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onChange((val: string) => {
                this.password = val;
              })
            Text(this.showPwdRegister ? '🙈' : '👁')
              .fontSize(18)
              .margin({ right: 14 })
              .onClick(() => {
                this.showPwdRegister = !this.showPwdRegister;
              })
          }
          .width('100%')
          .height(52)
          .backgroundColor(INPUT_BG)
          .borderRadius(14)
          .margin({ bottom: 16 })

          Text('确认密码')
            .fontSize(13)
            .fontColor(TEXT_MUTED)
            .width('100%')
            .margin({ bottom: 8 })
          Row() {
            Text('✓')
              .fontSize(18)
              .fontColor(PRIMARY_BLUE)
              .margin({ left: 14, right: 8 })
            TextInput({ placeholder: '请再次输入密码', text: this.confirmPassword })
              .type(this.showPwdConfirm ? InputType.Normal : InputType.Password)
              .placeholderColor(TEXT_MUTED)
              .fontColor('#111111')
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onChange((val: string) => {
                this.confirmPassword = val;
              })
            Text(this.showPwdConfirm ? '🙈' : '👁')
              .fontSize(18)
              .margin({ right: 14 })
              .onClick(() => {
                this.showPwdConfirm = !this.showPwdConfirm;
              })
          }
          .width('100%')
          .height(52)
          .backgroundColor(INPUT_BG)
          .borderRadius(14)
          .margin({ bottom: 16 })

          if (this.error.length > 0) {
            Text(this.error)
              .fontColor('#E53935')
              .fontSize(13)
              .width('100%')
              .margin({ bottom: 12 })
          }

          Button() {
            Row() {
              Text(this.loading ? '注册中...' : '注册')
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
              Text(' →')
                .fontSize(17)
                .fontColor(Color.White)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
          }
          .width('100%')
          .height(52)
          .backgroundColor(PRIMARY_BLUE)
          .borderRadius(16)
          .enabled(!this.loading)
          .onClick(() => {
            void this.submit();
          })

          Row() {
            Text('已有账号？')
              .fontSize(14)
              .fontColor(TEXT_MUTED)
            Text('去登录')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(PRIMARY_BLUE)
              .onClick(() => {
                this.tab = 0;
                this.error = '';
                this.confirmPassword = '';
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 18 })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 22, bottom: 22 })
        .backgroundColor(Color.White)
        .borderRadius(28)
        .shadow({ radius: 24, color: '#00000012', offsetY: 8 })
        .margin({ top: 24, bottom: 24 })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
