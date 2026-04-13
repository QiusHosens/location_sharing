import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { HttpClient } from '../api/HttpClient';

@Entry
@Component
struct LoginPage {
  @State phone: string = '';
  @State code: string = '';
  @State step: number = 0;
  @State error: string = '';
  @State loading: boolean = false;

  async sendCode(): Promise<void> {
    if (this.phone.length < 11) { this.error = '请输入正确的手机号'; return; }
    this.loading = true;
    this.error = '';
    try {
      await HttpClient.post('/auth/send-code', { phone: this.phone });
      this.step = 1;
    } catch (e) {
      this.error = '发送验证码失败';
    } finally {
      this.loading = false;
    }
  }

  async verify(): Promise<void> {
    if (this.code.length !== 6) { this.error = '请输入6位验证码'; return; }
    this.loading = true;
    this.error = '';
    try {
      const res = await HttpClient.post('/auth/verify-code', { phone: this.phone, code: this.code }) as Record<string, object>;
      const data = res['data'] as Record<string, string>;
      const store = await preferences.getPreferences(getContext(this), 'auth');
      await store.put('token', data['access_token']);
      await store.put('user_id', data['user_id']);
      await store.put('phone', this.phone);
      await store.flush();
      HttpClient.setToken(data['access_token']);
      router.replaceUrl({ url: 'pages/MapPage' });
    } catch (e) {
      this.error = '验证码错误';
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Image($r('app.media.app_icon')).width(64).height(64).margin({ bottom: 8 })
      Text('定位共享').fontSize(24).fontWeight(FontWeight.Bold)
      Text('家人位置，安心守护').fontSize(14).fontColor('#999').margin({ bottom: 32 })

      if (this.error) {
        Text(this.error).fontColor(Color.Red).fontSize(14).margin({ bottom: 16 })
      }

      if (this.step === 0) {
        TextInput({ placeholder: '手机号', text: this.phone })
          .type(InputType.PhoneNumber)
          .maxLength(15)
          .onChange((val: string) => { this.phone = val; })
          .width('100%')
          .margin({ bottom: 16 })

        Button(this.loading ? '发送中...' : '获取验证码')
          .width('100%')
          .enabled(!this.loading)
          .onClick(() => this.sendCode())
      } else {
        Text('验证码已发送至 ' + this.phone).fontSize(14).fontColor('#666').margin({ bottom: 16 })

        TextInput({ placeholder: '验证码', text: this.code })
          .type(InputType.Number)
          .maxLength(6)
          .onChange((val: string) => { this.code = val; })
          .width('100%')
          .margin({ bottom: 16 })

        Button(this.loading ? '登录中...' : '登 录')
          .width('100%')
          .enabled(!this.loading)
          .onClick(() => this.verify())
          .margin({ bottom: 8 })

        Button('重新发送').type(ButtonType.Normal).fontColor('#2196F3').backgroundColor(Color.Transparent)
          .onClick(() => this.sendCode())
      }
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }
}
