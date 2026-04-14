import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { HttpClient } from '../api/HttpClient';
import { GroupCreateBody } from '../api/ApiPayloads';
import { MainBottomNav } from '../components/MainBottomNav';
import { AppTheme } from '../common/AppTheme';

interface GroupMember {
  user_id: string;
  phone: string;
  nickname: string | null;
  role: string;
}

interface FamilyGroup {
  id: string;
  name: string;
  creator_id: string;
  members: GroupMember[];
}

@Entry
@Component
struct FamilyPage {
  @State groups: FamilyGroup[] = [];
  @State showCreateDialog: boolean = false;
  @State newGroupName: string = '';
  @State headerLetter: string = '?';

  aboutToAppear(): void {
    HttpClient.setContext(getContext(this));
    void this.initHeader();
    this.loadGroups();
  }

  async initHeader(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), 'auth');
      const phone = await store.get('phone', '') as string;
      this.headerLetter = phone.length > 0 ? phone.substring(0, 1).toUpperCase() : '?';
    } catch {
      this.headerLetter = '?';
    }
  }

  async loadGroups(): Promise<void> {
    try {
      const res = await HttpClient.get('/groups') as Record<string, object>;
      this.groups = (res['data'] as FamilyGroup[]) ?? [];
    } catch {
      /* ignore */
    }
  }

  async createGroup(): Promise<void> {
    try {
      const body: GroupCreateBody = { name: this.newGroupName };
      await HttpClient.post('/groups', body);
      this.showCreateDialog = false;
      this.newGroupName = '';
      await this.loadGroups();
    } catch {
      /* ignore */
    }
  }

  async deleteGroup(id: string): Promise<void> {
    try {
      await HttpClient.del('/groups/' + id);
      await this.loadGroups();
    } catch {
      /* ignore */
    }
  }

  build() {
    Stack() {
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
        Text('家庭')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
          .margin({ left: 10 })
        Button({ type: ButtonType.Circle }) {
          Text('🔔').fontSize(16)
        }
          .width(40)
          .height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => router.pushUrl({ url: 'pages/NotificationsPage' }))
        Button('+')
          .fontSize(20)
          .fontColor(AppTheme.accentBlue)
          .backgroundColor(Color.Transparent)
          .onClick(() => { this.showCreateDialog = true; })
      }
      .width('100%')
      .padding({ left: 16, right: 8, top: 8, bottom: 12 })

      if (this.groups.length === 0) {
        Text('暂无家庭组')
          .fontSize(15)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 64 })
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.groups, (group: FamilyGroup) => {
            ListItem() {
              Column() {
                Row() {
                  Text(group.name)
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.textPrimary)
                    .layoutWeight(1)
                  Text(group.members.length + ' 人')
                    .fontSize(12)
                    .fontColor(AppTheme.textSecondary)
                }
                .width('100%')
                ForEach(group.members, (m: GroupMember) => {
                  Row() {
                    Text((m.nickname ?? m.phone).substring(0, 1))
                      .fontSize(12)
                      .fontColor(Color.White)
                      .width(28)
                      .height(28)
                      .borderRadius(14)
                      .backgroundColor(AppTheme.accentBlue)
                      .textAlign(TextAlign.Center)
                    Text(m.nickname ?? m.phone)
                      .fontSize(14)
                      .fontColor(AppTheme.textPrimary)
                      .margin({ left: 8 })
                      .layoutWeight(1)
                    Text(m.role === 'owner' ? '创建者' : '成员')
                      .fontSize(12)
                      .fontColor(AppTheme.textSecondary)
                  }
                  .width('100%')
                  .margin({ top: 8 })
                })
                Button('删除该组')
                  .fontSize(13)
                  .fontColor('#E53935')
                  .backgroundColor(Color.Transparent)
                  .margin({ top: 12 })
                  .onClick(() => void this.deleteGroup(group.id))
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(16)
              .margin({ bottom: 12 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }

      MainBottomNav({ currentIndex: 1 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.pageBg)

      if (this.showCreateDialog) {
      Column() {
        Text('创建家庭组')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
          .margin({ bottom: 16 })
        TextInput({ placeholder: '家庭组名称', text: this.newGroupName })
          .onChange((val: string) => {
            this.newGroupName = val;
          })
          .width('100%')
          .margin({ bottom: 16 })
        Row() {
          Button('取消')
            .layoutWeight(1)
            .backgroundColor('#EEEEEE')
            .fontColor('#333333')
            .onClick(() => { this.showCreateDialog = false; })
          Button('创建')
            .layoutWeight(1)
            .margin({ left: 8 })
            .backgroundColor(AppTheme.accentBlue)
            .onClick(() => void this.createGroup())
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
