import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { HttpClient } from '../api/HttpClient';
import { ProfileUpdateBody } from '../api/ApiPayloads';
import { MainBottomNav } from '../components/MainBottomNav';
import { AppTheme } from '../common/AppTheme';
import { resolveMediaUrl } from '../common/MediaUrl';

interface ProfileData {
  nickname?: string;
  phone?: string;
  avatar_url?: string;
}

interface ProfileGetResponse {
  data?: ProfileData;
}

function maskPhoneDisplay(raw: string): string {
  if (!raw || raw.length === 0) {
    return '—';
  }
  const t = raw.replace(/\s/g, '');
  if (t.length === 11 && /^\d{11}$/.test(t)) {
    return '+86 ' + t.substring(0, 3) + ' **** ' + t.substring(7);
  }
  if (t.length >= 8) {
    return t.substring(0, 3) + ' **** ' + t.substring(t.length - 4);
  }
  return raw;
}

@Entry
@Component
struct SettingsPage {
  @State nickname: string = '';
  @State phone: string = '';
  @State avatarUrl: string = '';
  @State headerLetter: string = '?';
  private static readonly displayVersion: string = '0.1.0';

  aboutToAppear(): void {
    HttpClient.setContext(getContext(this));
    void this.initHeader();
    void this.loadProfile();
  }

  async initHeader(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), 'auth');
      const p = await store.get('phone', '') as string;
      const uid = await store.get('user_id', '') as string;
      const letter = (p.length > 0 ? p : uid).toString();
      this.headerLetter = letter.length > 0 ? letter.substring(0, 1).toUpperCase() : '?';
    } catch {
      this.headerLetter = '?';
    }
  }

  async loadProfile(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), 'auth');
      const prefPhone = await store.get('phone', '') as string;
      this.phone = prefPhone;
      const res = await HttpClient.get('/users/profile') as ProfileGetResponse;
      const data = res.data;
      if (data) {
        this.nickname = data.nickname ?? '';
        if (data.phone && data.phone.length > 0) {
          this.phone = data.phone;
        }
        this.avatarUrl = resolveMediaUrl(data.avatar_url);
      }
    } catch {
      /* ignore */
    }
  }

  async saveProfile(): Promise<void> {
    try {
      const body: ProfileUpdateBody = { nickname: this.nickname };
      await HttpClient.put('/users/profile', body);
      promptAction.showToast({ message: '已保存' });
    } catch {
      promptAction.showToast({ message: '保存失败' });
    }
  }

  async logout(): Promise<void> {
    const store = await preferences.getPreferences(getContext(this), 'auth');
    await store.clear();
    await store.flush();
    HttpClient.clearSession();
    router.replaceUrl({ url: 'pages/LoginPage' });
  }

  onLegalTap(title: string): void {
    promptAction.showToast({ message: title + '（内容即将接入）' });
  }

  build() {
    Column() {
      Row() {
        Text(this.headerLetter)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.brandBlue)
          .width(44)
          .height(44)
          .borderRadius(22)
          .textAlign(TextAlign.Center)
          .backgroundColor('#E3F2FD')
        Text('位置共享')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
          .margin({ left: 10 })
        Button({ type: ButtonType.Circle }) {
          Text('🔔').fontSize(16)
        }
          .width(40)
          .height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            router.pushUrl({ url: 'pages/NotificationsPage' });
          })
      }
      .width('100%')
      .padding({ left: 12, right: 8, top: 8, bottom: 8 })

      Text('设置与个人中心')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.textPrimary)
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 16 })

      Scroll() {
        Column() {
          Column() {
            Stack({ alignContent: Alignment.BottomEnd }) {
              if (this.avatarUrl.length > 0) {
                Image(this.avatarUrl)
                  .width(112)
                  .height(112)
                  .borderRadius(16)
                  .objectFit(ImageFit.Cover)
              } else {
                Column() {
                  Text(this.headerLetter)
                    .fontSize(40)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.brandBlue)
                }
                .width(112)
                .height(112)
                .borderRadius(16)
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#E3F2FD')
              }
              Text('✎')
                .fontSize(14)
                .fontColor(Color.White)
                .width(32)
                .height(32)
                .borderRadius(16)
                .textAlign(TextAlign.Center)
                .backgroundColor(AppTheme.accentBlue)
                .margin({ right: -4, bottom: -4 })
            }
            .width(112)
            .height(112)
            .margin({ bottom: 12 })

            Text('点击更换头像')
              .fontSize(13)
              .fontColor(AppTheme.textSecondary)
              .margin({ bottom: 28 })

            Text('用户昵称')
              .fontSize(13)
              .fontColor(AppTheme.textSecondary)
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ bottom: 8 })

            TextInput({ placeholder: '昵称', text: this.nickname })
              .onChange((val: string) => {
                this.nickname = val;
              })
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(AppTheme.pageBg)
              .borderRadius(14)
              .margin({ bottom: 20 })

            Text('手机号码')
              .fontSize(13)
              .fontColor(AppTheme.textSecondary)
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ bottom: 8 })

            Text(maskPhoneDisplay(this.phone))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(AppTheme.pageBg)
              .borderRadius(14)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 24, bottom: 24 })
          .backgroundColor(Color.White)
          .borderRadius(16)

          Button('保存修改')
            .width('100%')
            .margin({ top: 16 })
            .backgroundColor(AppTheme.accentBlue)
            .onClick(() => {
              void this.saveProfile();
            })

          Button('退出登录')
            .width('100%')
            .margin({ top: 24 })
            .backgroundColor(Color.White)
            .fontColor('#E53935')
            .borderWidth(1.2)
            .borderColor('#E53935')
            .onClick(() => {
              void this.logout();
            })

          Row() {
            Text('版本 ' + SettingsPage.displayVersion + ' • ')
              .fontSize(12)
              .fontColor(AppTheme.textSecondary)
            Text('隐私政策')
              .fontSize(12)
              .fontColor(AppTheme.brandBlue)
              .onClick(() => {
                this.onLegalTap('隐私政策');
              })
            Text(' 与 ')
              .fontSize(12)
              .fontColor(AppTheme.textSecondary)
            Text('服务条款')
              .fontSize(12)
              .fontColor(AppTheme.brandBlue)
              .onClick(() => {
                this.onLegalTap('服务条款');
              })
          }
          .width('100%')
          .margin({ top: 20, bottom: 32 })
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      MainBottomNav({ currentIndex: 3 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBg)
  }
}
