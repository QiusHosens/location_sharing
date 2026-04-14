import { promptAction } from '@kit.ArkUI';
import { HttpClient } from '../api/HttpClient';
import { SharingRespondBody, SharingRequestBody, SharingUpdateBody } from '../api/ApiPayloads';
import { MainBottomNav } from '../components/MainBottomNav';
import { AppTheme } from '../common/AppTheme';

interface SharingItem {
  id: string;
  owner_id: string;
  viewer_id: string;
  status: string;
  is_paused: boolean;
  peer_nickname: string | null;
  peer_phone: string;
}

interface SharingListResponse {
  data?: SharingItem[];
}

@Entry
@Component
struct SharingPage {
  @State sharingList: SharingItem[] = [];
  @State showRequestDialog: boolean = false;
  @State requestPhone: string = '';

  aboutToAppear(): void {
    HttpClient.setContext(getContext(this));
    void this.load();
  }

  async load(): Promise<void> {
    try {
      const res = await HttpClient.get('/sharing') as SharingListResponse;
      this.sharingList = res.data ?? [];
    } catch {
      /* ignore */
    }
  }

  async respond(id: string, accept: boolean): Promise<void> {
    try {
      const body: SharingRespondBody = { accept: accept };
      await HttpClient.put('/sharing/' + id + '/respond', body);
      await this.load();
    } catch {
      /* ignore */
    }
  }

  async togglePause(id: string, currentlyPaused: boolean): Promise<void> {
    try {
      const body: SharingUpdateBody = { is_paused: !currentlyPaused };
      await HttpClient.put('/sharing/' + id, body);
      await this.load();
    } catch {
      /* ignore */
    }
  }

  async deleteSh(id: string): Promise<void> {
    try {
      await HttpClient.del('/sharing/' + id);
      await this.load();
    } catch {
      /* ignore */
    }
  }

  async sendRequest(): Promise<void> {
    const t = this.requestPhone.trim();
    if (t.length < 11) {
      promptAction.showToast({ message: '请输入对方手机号' });
      return;
    }
    try {
      const body: SharingRequestBody = { phone: t };
      await HttpClient.post('/sharing', body);
      this.showRequestDialog = false;
      this.requestPhone = '';
      await this.load();
      promptAction.showToast({ message: '请求已发送' });
    } catch {
      promptAction.showToast({ message: '发送失败' });
    }
  }

  peerInitial(s: SharingItem): string {
    const label = (s.peer_nickname ?? s.peer_phone ?? '?').toString();
    return label.length > 0 ? label.substring(0, 1).toUpperCase() : '?';
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('位置共享')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.textPrimary)
            .layoutWeight(1)
          Button({ type: ButtonType.Circle }) {
            Text('+')
              .fontSize(22)
              .fontColor(AppTheme.accentBlue)
          }
            .width(40)
            .height(40)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showRequestDialog = true;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 8, top: 12, bottom: 8 })

        if (this.sharingList.length === 0) {
          Text('暂无共享记录')
            .fontSize(15)
            .fontColor(AppTheme.textSecondary)
            .margin({ top: 64 })
            .layoutWeight(1)
        } else {
          List() {
            ForEach(this.sharingList, (s: SharingItem) => {
              ListItem() {
                Row() {
                  Text(this.peerInitial(s))
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                    .width(44)
                    .height(44)
                    .borderRadius(22)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(AppTheme.accentBlue)
                  Column() {
                    Text(s.peer_nickname ?? s.peer_phone)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.textPrimary)
                    Text(s.status === 'accepted' ? '已接受' : s.status === 'pending' ? '待确认' : '已拒绝')
                      .fontSize(12)
                      .fontColor(s.status === 'accepted' ? '#4CAF50' : s.status === 'pending' ? '#FF9800' : '#F44336')
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .margin({ left: 12 })

                  Row() {
                    if (s.status === 'pending') {
                      Button('✓')
                        .width(36)
                        .height(36)
                        .fontSize(16)
                        .fontColor('#4CAF50')
                        .backgroundColor(Color.Transparent)
                        .onClick(() => {
                          void this.respond(s.id, true);
                        })
                      Button('✕')
                        .width(36)
                        .height(36)
                        .fontSize(16)
                        .fontColor('#F44336')
                        .backgroundColor(Color.Transparent)
                        .onClick(() => {
                          void this.respond(s.id, false);
                        })
                    }
                    if (s.status === 'accepted') {
                      Button(s.is_paused ? '恢复' : '暂停')
                        .height(32)
                        .fontSize(12)
                        .fontColor(AppTheme.textPrimary)
                        .backgroundColor(AppTheme.pageBg)
                        .onClick(() => {
                          void this.togglePause(s.id, s.is_paused);
                        })
                    }
                    Button('删除')
                      .height(32)
                      .fontSize(12)
                      .fontColor('#F44336')
                      .backgroundColor(Color.Transparent)
                      .margin({ left: 4 })
                      .onClick(() => {
                        void this.deleteSh(s.id);
                      })
                  }
                }
                .width('100%')
                .padding(16)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .margin({ bottom: 8 })
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
        }

        MainBottomNav({ currentIndex: 3 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.pageBg)

      if (this.showRequestDialog) {
        Column() {
          Text('请求位置共享')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.textPrimary)
            .margin({ bottom: 16 })
          TextInput({ placeholder: '对方手机号（已注册账号）', text: this.requestPhone })
            .type(InputType.PhoneNumber)
            .onChange((val: string) => {
              this.requestPhone = val;
            })
            .width('100%')
            .margin({ bottom: 16 })
          Row() {
            Button('取消')
              .layoutWeight(1)
              .backgroundColor('#EEEEEE')
              .fontColor('#333333')
              .onClick(() => {
                this.showRequestDialog = false;
                this.requestPhone = '';
              })
            Button('发送')
              .layoutWeight(1)
              .margin({ left: 8 })
              .backgroundColor(AppTheme.accentBlue)
              .onClick(() => {
                void this.sendRequest();
              })
          }
          .width('100%')
        }
        .width('86%')
        .padding(24)
        .backgroundColor(Color.White)
        .borderRadius(16)
        .position({ x: '7%', y: '28%' })
      }
    }
    .width('100%')
    .height('100%')
  }
}
