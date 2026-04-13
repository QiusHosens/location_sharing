import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { HttpClient } from '../api/HttpClient';

@Entry
@Component
struct SettingsPage {
  @State nickname: string = '';
  @State phone: string = '';

  aboutToAppear(): void { this.loadProfile(); }

  async loadProfile(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), 'auth');
      this.phone = await store.get('phone', '') as string;
      const res = await HttpClient.get('/users/profile') as Record<string, object>;
      const data = res['data'] as Record<string, string>;
      this.nickname = data['nickname'] ?? '';
    } catch (e) {}
  }

  async saveProfile(): Promise<void> {
    try {
      await HttpClient.put('/users/profile', { nickname: this.nickname });
    } catch (e) {}
  }

  async logout(): Promise<void> {
    const store = await preferences.getPreferences(getContext(this), 'auth');
    await store.clear();
    await store.flush();
    HttpClient.clearToken();
    router.replaceUrl({ url: 'pages/LoginPage' });
  }

  build() {
    Column() {
      Text('设置').fontSize(20).fontWeight(FontWeight.Bold).padding(16).width('100%')

      Column() {
        Text(this.nickname || '未设置昵称').fontSize(18).fontWeight(FontWeight.Bold)
        Text(this.phone).fontSize(14).fontColor('#999').margin({ top: 4 })
      }
      .width('100%')
      .padding(24)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 16, right: 16, bottom: 16 })
      .alignItems(HorizontalAlign.Center)

      Column() {
        TextInput({ placeholder: '昵称', text: this.nickname })
          .onChange((val: string) => { this.nickname = val; })
          .width('100%')
          .margin({ bottom: 16 })
        Button('保存修改').width('100%').onClick(() => this.saveProfile())
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 16, right: 16, bottom: 16 })

      Column() {
        Row() {
          Text('关于').fontSize(14).layoutWeight(1)
          Text('定位共享 v0.1.0').fontSize(12).fontColor('#999')
        }.width('100%').padding(16)
        Divider()
        Row() {
          Text('退出登录').fontSize(14).fontColor('#f44336')
        }.width('100%').padding(16).onClick(() => this.logout())
      }
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 16, right: 16 })

      Blank()

      Row() {
        this.navItem('地图', 'pages/MapPage')
        this.navItem('家庭', 'pages/FamilyPage')
        this.navItem('共享', 'pages/SharingPage')
        this.navItem('轨迹', 'pages/TrajectoryPage')
        this.navItem('通知', 'pages/NotificationsPage')
        this.navItem('设置', '')
      }.width('100%').height(56).justifyContent(FlexAlign.SpaceAround).borderWidth({ top: 1 }).borderColor('#e0e0e0')
    }.width('100%').height('100%').backgroundColor('#f5f5f5')
  }

  @Builder navItem(label: string, page: string) {
    Column() { Text(label).fontSize(12).fontColor(page === '' ? '#2196F3' : '#999') }
    .onClick(() => { if (page) router.replaceUrl({ url: page }); }).justifyContent(FlexAlign.Center).height('100%')
  }
}
