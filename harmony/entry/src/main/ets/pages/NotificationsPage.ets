import { HttpClient } from '../api/HttpClient';
import { appendNotificationListQuery, NotificationListParams } from '../api/ApiPayloads';
import { MainBottomNav } from '../components/MainBottomNav';
import { AppTheme } from '../common/AppTheme';

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

interface NotificationsApiResponse {
  data?: NotificationsListData;
}

@Entry
@Component
struct NotificationsPage {
  @State notifications: NotificationItem[] = [];
  @State unreadCount: number = 0;

  aboutToAppear(): void {
    HttpClient.setContext(getContext(this));
    void this.load();
  }

  async load(): Promise<void> {
    try {
      const query: NotificationListParams = { page: '1', page_size: '20' };
      const pathWithQuery = appendNotificationListQuery('/notifications', query);
      const res = await HttpClient.get(pathWithQuery) as NotificationsApiResponse;
      const data = res.data;
      this.notifications = data?.items ?? [];
      this.unreadCount = data?.unread_count ?? 0;
    } catch {
      /* ignore */
    }
  }

  async markRead(id: string): Promise<void> {
    try {
      await HttpClient.put('/notifications/' + id + '/read');
      await this.load();
    } catch {
      /* ignore */
    }
  }

  async markAllRead(): Promise<void> {
    try {
      await HttpClient.put('/notifications/read-all');
      await this.load();
    } catch {
      /* ignore */
    }
  }

  build() {
    Column() {
      Row() {
        Text('通知中心')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
        if (this.unreadCount > 0) {
          Button('全部已读')
            .height(36)
            .fontSize(13)
            .fontColor(AppTheme.accentBlue)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              void this.markAllRead();
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.notifications.length === 0) {
        Text('暂无通知')
          .fontSize(15)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 64 })
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.notifications, (n: NotificationItem) => {
            ListItem() {
              Row() {
                Column() {
                  Text(n.title ?? n.type)
                    .fontSize(15)
                    .fontWeight(n.is_read ? FontWeight.Normal : FontWeight.Bold)
                    .fontColor(AppTheme.textPrimary)
                  if (n.body) {
                    Text(n.body)
                      .fontSize(14)
                      .fontColor(AppTheme.textSecondary)
                      .margin({ top: 6 })
                  }
                  Text(n.created_at)
                    .fontSize(12)
                    .fontColor('#9CA3AF')
                    .margin({ top: 6 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (!n.is_read) {
                  Button('已读')
                    .height(32)
                    .fontSize(12)
                    .fontColor(AppTheme.brandBlue)
                    .backgroundColor(Color.Transparent)
                    .onClick(() => {
                      void this.markRead(n.id);
                    })
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(n.is_read ? Color.White : '#E3F2FD')
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
  }
}
