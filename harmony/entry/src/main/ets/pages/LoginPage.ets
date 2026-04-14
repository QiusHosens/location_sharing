import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { HttpClient } from '../api/HttpClient';
import { AuthPasswordBody } from '../api/ApiPayloads';

@Entry
@Component
struct LoginPage {
  @State phone: string = '';
  @State password: string = '';
  @State tab: number = 0;
  @State error: string = '';
  @State loading: boolean = false;

  async submit(): Promise<void> {
    if (this.phone.length < 11) { this.error = '请输入正确的手机号'; return; }
    if (!this.password) { this.error = '请输入密码'; return; }
    this.loading = true;
    this.error = '';
    const path = this.tab === 0 ? '/auth/login' : '/auth/register';
    try {
      const body: AuthPasswordBody = { phone: this.phone, password: this.password };
      const res = await HttpClient.post(path, body) as Record<string, object>;
      const data = res['data'] as Record<string, string>;
      const store = await preferences.getPreferences(getContext(this), 'auth');
      await store.put('token', data['access_token']);
      await store.put('refresh_token', data['refresh_token']);
      await store.put('user_id', data['user_id']);
      await store.put('phone', this.phone);
      await store.flush();
      HttpClient.setContext(getContext(this));
      HttpClient.setSession(data['access_token'], data['refresh_token']);
      router.replaceUrl({ url: 'pages/MapPage' });
    } catch (e) {
      this.error = this.tab === 0 ? '登录失败' : '注册失败';
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Image($r('app.media.app_icon')).width(64).height(64).margin({ bottom: 8 })
      Text('定位共享').fontSize(24).fontWeight(FontWeight.Bold)
      Text('家人位置，安心守护').fontSize(14).fontColor('#999').margin({ bottom: 24 })

      Row() {
        Button('登录').layoutWeight(1).type(this.tab === 0 ? ButtonType.Capsule : ButtonType.Normal)
          .onClick(() => { this.tab = 0; this.error = ''; })
        Button('注册').layoutWeight(1).type(this.tab === 1 ? ButtonType.Capsule : ButtonType.Normal)
          .onClick(() => { this.tab = 1; this.error = ''; })
      }.width('100%').margin({ bottom: 16 })

      if (this.error) {
        Text(this.error).fontColor(Color.Red).fontSize(14).margin({ bottom: 16 })
      }

      TextInput({ placeholder: '手机号', text: this.phone })
        .type(InputType.PhoneNumber)
        .maxLength(15)
        .onChange((val: string) => { this.phone = val; })
        .width('100%')
        .margin({ bottom: 16 })

      TextInput({ placeholder: '密码', text: this.password })
        .type(InputType.Password)
        .onChange((val: string) => { this.password = val; })
        .width('100%')
        .margin({ bottom: 16 })

      Button(this.loading ? '提交中...' : '提交')
        .width('100%')
        .enabled(!this.loading)
        .onClick(() => this.submit())
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }
}
