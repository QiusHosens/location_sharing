import { router } from '@kit.ArkUI';
import { HttpClient } from '../api/HttpClient';
import { appendNotificationListQuery, NotificationListParams } from '../api/ApiPayloads';

interface NotificationItem {
  id: string;
  type: string;
  title: string | null;
  body: string | null;
  is_read: boolean;
  created_at: string;
}

interface NotificationsListData {
  items?: NotificationItem[];
  unread_count?: number;
}

@Entry
@Component
struct NotificationsPage {
  @State notifications: NotificationItem[] = [];
  @State unreadCount: number = 0;

  aboutToAppear(): void { this.load(); }

  async load(): Promise<void> {
    try {
      const query: NotificationListParams = { page: '1', page_size: '20' };
      const pathWithQuery = appendNotificationListQuery('/notifications', query);
      const res = await HttpClient.get(pathWithQuery) as Record<string, object>;
      const data = res['data'] as NotificationsListData;
      this.notifications = data.items ?? [];
      this.unreadCount = data.unread_count ?? 0;
    } catch (e) {}
  }

  async markRead(id: string): Promise<void> {
    try { await HttpClient.put('/notifications/' + id + '/read'); await this.load(); } catch (e) {}
  }

  async markAllRead(): Promise<void> {
    try { await HttpClient.put('/notifications/read-all'); await this.load(); } catch (e) {}
  }

  build() {
    Column() {
      Row() {
        Text('通知中心').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
        if (this.unreadCount > 0) {
          Button('全部已读').height(32).fontSize(12).onClick(() => this.markAllRead())
        }
      }.width('100%').padding(16)

      if (this.notifications.length === 0) {
        Text('暂无通知').fontSize(14).fontColor('#999').margin({ top: 64 })
      } else {
        List() {
          ForEach(this.notifications, (n: NotificationItem) => {
            ListItem() {
              Row() {
                Column() {
                  Text(n.title ?? n.type).fontSize(14).fontWeight(n.is_read ? FontWeight.Normal : FontWeight.Bold)
                  if (n.body) { Text(n.body).fontSize(12).fontColor('#666').margin({ top: 4 }) }
                  Text(n.created_at).fontSize(11).fontColor('#999').margin({ top: 4 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                if (!n.is_read) {
                  Button('已读').height(28).fontSize(11).onClick(() => this.markRead(n.id))
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(n.is_read ? Color.White : '#e3f2fd')
              .borderRadius(8)
              .margin({ bottom: 4 })
            }
          })
        }.width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
      }

      Row() {
        this.navItem('地图', 'pages/MapPage')
        this.navItem('家庭', 'pages/FamilyPage')
        this.navItem('共享', 'pages/SharingPage')
        this.navItem('轨迹', 'pages/TrajectoryPage')
        this.navItem('通知', '')
        this.navItem('设置', 'pages/SettingsPage')
      }.width('100%').height(56).justifyContent(FlexAlign.SpaceAround).borderWidth({ top: 1 }).borderColor('#e0e0e0')
    }.width('100%').height('100%').backgroundColor('#f5f5f5')
  }

  @Builder navItem(label: string, page: string) {
    Column() { Text(label).fontSize(12).fontColor(page === '' ? '#2196F3' : '#999') }
    .onClick(() => { if (page) router.replaceUrl({ url: page }); }).justifyContent(FlexAlign.Center).height('100%')
  }
}
