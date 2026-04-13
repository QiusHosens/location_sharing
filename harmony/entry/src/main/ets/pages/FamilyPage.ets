import { router } from '@kit.ArkUI';
import { HttpClient } from '../api/HttpClient';

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

  aboutToAppear(): void { this.loadGroups(); }

  async loadGroups(): Promise<void> {
    try {
      const res = await HttpClient.get('/groups') as Record<string, object>;
      this.groups = (res['data'] as FamilyGroup[]) ?? [];
    } catch (e) {}
  }

  async createGroup(): Promise<void> {
    try {
      await HttpClient.post('/groups', { name: this.newGroupName });
      this.showCreateDialog = false;
      this.newGroupName = '';
      await this.loadGroups();
    } catch (e) {}
  }

  async deleteGroup(id: string): Promise<void> {
    try { await HttpClient.del('/groups/' + id); await this.loadGroups(); } catch (e) {}
  }

  build() {
    Column() {
      Row() {
        Text('家庭组').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
        Button('+').width(36).height(36).onClick(() => { this.showCreateDialog = true; })
      }.width('100%').padding(16)

      if (this.groups.length === 0) {
        Text('暂无家庭组').fontSize(14).fontColor('#999').margin({ top: 64 })
      } else {
        List() {
          ForEach(this.groups, (group: FamilyGroup) => {
            ListItem() {
              Column() {
                Row() {
                  Text(group.name).fontSize(16).fontWeight(FontWeight.Bold).layoutWeight(1)
                  Text(group.members.length + '人').fontSize(12).fontColor('#999')
                }.width('100%')
                ForEach(group.members, (m: GroupMember) => {
                  Row() {
                    Text((m.nickname ?? m.phone)[0]).fontSize(12).fontColor(Color.White)
                      .width(28).height(28).borderRadius(14).backgroundColor('#2196F3')
                      .textAlign(TextAlign.Center)
                    Text(m.nickname ?? m.phone).fontSize(14).margin({ left: 8 }).layoutWeight(1)
                    Text(m.role === 'owner' ? '创建者' : '成员').fontSize(12).fontColor('#999')
                  }.width('100%').margin({ top: 8 })
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .margin({ bottom: 12 })
            }
          })
        }.width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
      }

      // 底部导航（复用结构）
      Row() {
        this.navItem('地图', 'pages/MapPage')
        this.navItem('家庭', '')
        this.navItem('共享', 'pages/SharingPage')
        this.navItem('轨迹', 'pages/TrajectoryPage')
        this.navItem('通知', 'pages/NotificationsPage')
        this.navItem('设置', 'pages/SettingsPage')
      }.width('100%').height(56).justifyContent(FlexAlign.SpaceAround).borderWidth({ top: 1 }).borderColor('#e0e0e0')

      if (this.showCreateDialog) {
        Column() {
          Text('创建家庭组').fontSize(18).fontWeight(FontWeight.Bold).margin({ bottom: 16 })
          TextInput({ placeholder: '家庭组名称', text: this.newGroupName })
            .onChange((val: string) => { this.newGroupName = val; }).width('100%').margin({ bottom: 16 })
          Row() {
            Button('取消').backgroundColor('#eee').fontColor('#333').onClick(() => { this.showCreateDialog = false; }).layoutWeight(1).margin({ right: 8 })
            Button('创建').onClick(() => this.createGroup()).layoutWeight(1)
          }.width('100%')
        }
        .width('80%').padding(24).backgroundColor(Color.White).borderRadius(16)
        .position({ x: '10%', y: '30%' })
      }
    }.width('100%').height('100%').backgroundColor('#f5f5f5')
  }

  @Builder navItem(label: string, page: string) {
    Column() {
      Text(label).fontSize(12).fontColor(page === '' ? '#2196F3' : '#999')
    }.onClick(() => { if (page) router.replaceUrl({ url: page }); }).justifyContent(FlexAlign.Center).height('100%')
  }
}
