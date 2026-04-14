import { router } from '@kit.ArkUI';
import { HttpClient } from '../api/HttpClient';
import { SharingRespondBody } from '../api/ApiPayloads';

interface SharingItem {
  id: string;
  owner_id: string;
  viewer_id: string;
  status: string;
  is_paused: boolean;
  peer_nickname: string | null;
  peer_phone: string;
}

@Entry
@Component
struct SharingPage {
  @State sharingList: SharingItem[] = [];

  aboutToAppear(): void { this.load(); }

  async load(): Promise<void> {
    try {
      const res = await HttpClient.get('/sharing') as Record<string, object>;
      this.sharingList = (res['data'] as SharingItem[]) ?? [];
    } catch (e) {}
  }

  async respond(id: string, accept: boolean): Promise<void> {
    try {
      const body: SharingRespondBody = { accept: accept };
      await HttpClient.put('/sharing/' + id + '/respond', body);
      await this.load();
    } catch (e) {}
  }

  async deleteSh(id: string): Promise<void> {
    try { await HttpClient.del('/sharing/' + id); await this.load(); } catch (e) {}
  }

  build() {
    Column() {
      Row() {
        Text('位置共享').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
      }.width('100%').padding(16)

      if (this.sharingList.length === 0) {
        Text('暂无共享记录').fontSize(14).fontColor('#999').margin({ top: 64 })
      } else {
        List() {
          ForEach(this.sharingList, (s: SharingItem) => {
            ListItem() {
              Row() {
                Column() {
                  Text(s.peer_nickname ?? s.peer_phone).fontSize(14).fontWeight(FontWeight.Bold)
                  Text(s.status === 'accepted' ? '已接受' : s.status === 'pending' ? '待确认' : '已拒绝')
                    .fontSize(12)
                    .fontColor(s.status === 'accepted' ? '#4caf50' : s.status === 'pending' ? '#ff9800' : '#f44336')
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                if (s.status === 'pending') {
                  Button('接受').height(32).fontSize(12).margin({ right: 4 }).onClick(() => this.respond(s.id, true))
                  Button('拒绝').height(32).fontSize(12).backgroundColor('#f44336').onClick(() => this.respond(s.id, false))
                }
                Button('删除').height(32).fontSize(12).backgroundColor('#ff5722').margin({ left: 4 }).onClick(() => this.deleteSh(s.id))
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .margin({ bottom: 8 })
            }
          })
        }.width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
      }

      Row() {
        this.navItem('地图', 'pages/MapPage')
        this.navItem('家庭', 'pages/FamilyPage')
        this.navItem('共享', '')
        this.navItem('轨迹', 'pages/TrajectoryPage')
        this.navItem('通知', 'pages/NotificationsPage')
        this.navItem('设置', 'pages/SettingsPage')
      }.width('100%').height(56).justifyContent(FlexAlign.SpaceAround).borderWidth({ top: 1 }).borderColor('#e0e0e0')
    }.width('100%').height('100%').backgroundColor('#f5f5f5')
  }

  @Builder navItem(label: string, page: string) {
    Column() { Text(label).fontSize(12).fontColor(page === '' ? '#2196F3' : '#999') }
    .onClick(() => { if (page) router.replaceUrl({ url: page }); }).justifyContent(FlexAlign.Center).height('100%')
  }
}
