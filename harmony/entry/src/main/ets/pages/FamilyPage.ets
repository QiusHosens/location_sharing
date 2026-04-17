import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { HttpClient } from '../api/HttpClient';
import { GroupCreateBody, InviteMemberBody } from '../api/ApiPayloads';
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
  @State selectedGroupId: string = '';
  @State currentGroup: FamilyGroup | null = null;
  @State myUserId: string = '';

  @State showInviteDialog: boolean = false;
  @State invitePhone: string = '';
  @State showMoreDialog: boolean = false;
  @State confirmDelete: boolean = false;

  aboutToAppear(): void {
    HttpClient.setContext(getContext(this));
    void this.initHeader();
    this.loadGroups();
  }

  async initHeader(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), 'auth');
      const phone = await store.get('phone', '') as string;
      const uid = await store.get('user_id', '') as string;
      this.myUserId = uid ?? '';
      this.headerLetter = phone.length > 0 ? phone.substring(0, 1).toUpperCase() : '?';
    } catch {
      this.headerLetter = '?';
    }
  }

  async loadGroups(): Promise<void> {
    try {
      const res = await HttpClient.get('/groups') as Record<string, object>;
      this.groups = (res['data'] as FamilyGroup[]) ?? [];
      if (this.selectedGroupId.length === 0 && this.groups.length > 0) {
        this.selectedGroupId = this.groups[0].id;
      }
      this.currentGroup = this.selectedGroup();
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

  isCreator(): boolean {
    if (this.currentGroup === null) return false;
    if (this.myUserId.length === 0) return false;
    return (this.currentGroup as FamilyGroup).creator_id === this.myUserId;
  }

  async inviteMember(): Promise<void> {
    if (this.currentGroup === null) return;
    if (!this.isCreator()) {
      promptAction.showToast({ message: '无权限' });
      return;
    }
    const phone = this.invitePhone.replace(/\s/g, '');
    if (phone.length !== 11 || !/^\d{11}$/.test(phone)) {
      promptAction.showToast({ message: '请输入11位手机号' });
      return;
    }
    try {
      const body: InviteMemberBody = { phone: phone };
      await HttpClient.post('/groups/' + (this.currentGroup as FamilyGroup).id + '/members', body);
      this.showInviteDialog = false;
      this.invitePhone = '';
      promptAction.showToast({ message: '邀请已发送' });
      await this.loadGroups();
    } catch {
      promptAction.showToast({ message: '发送失败' });
    }
  }

  selectedGroup(): FamilyGroup | null {
    if (this.groups.length === 0) return null;
    if (this.selectedGroupId.length === 0) return this.groups[0];
    const len = this.groups.length;
    for (let i = 0; i < len; i++) {
      const g = this.groups[i];
      if (g.id === this.selectedGroupId) return g;
    }
    return this.groups[0];
  }

  memberName(m: GroupMember): string {
    const nick = m.nickname ?? '';
    if (nick.length > 0) return nick;
    const p = m.phone ?? '';
    if (p.length > 0) return p;
    return '成员';
  }

  memberLetter(m: GroupMember): string {
    const name = this.memberName(m);
    return name.length > 0 ? name.substring(0, 1).toUpperCase() : '?';
  }

  memberSubtitle(m: GroupMember): string {
    // 目前后端未返回电量/状态，这里做占位（与截图文案风格对齐）
    const role = m.role === 'owner' ? '创建者' : '成员';
    return role + ' · — 电量';
  }

  build() {
    Stack() {
      Column() {
        // 顶部栏：头像 / 标题 / 通知
        Row() {
          Text(this.headerLetter)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width(44)
            .height(44)
            .borderRadius(22)
            .textAlign(TextAlign.Center)
            .backgroundColor(AppTheme.accentBlue)
          Text('家庭')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.textPrimary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Button({ type: ButtonType.Circle }) {
            Text('🔔')
              .fontSize(18)
              .fontColor(AppTheme.textPrimary)
          }
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => router.pushUrl({ url: 'pages/NotificationsPage' }))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })

        // 内容区
        Column() {
          if (this.currentGroup === null) {
            Column() {
              Text('暂无家庭组')
                .fontSize(15)
                .fontColor(AppTheme.textSecondary)
                .margin({ top: 80 })
            }
            .width('100%')
            .layoutWeight(1)
          } else {
            // 组信息（与截图一致：大号 ID/名称 + 成员数 + 邀请/更多）
            Row() {
              Column() {
                Text((this.currentGroup as FamilyGroup).name.length > 0 ? (this.currentGroup as FamilyGroup).name : (this.currentGroup as FamilyGroup).id)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.textPrimary)
                Text((this.currentGroup as FamilyGroup).members.length + ' 位成员')
                  .fontSize(13)
                  .fontColor(AppTheme.accentBlue)
                  .margin({ top: 6 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Row() {
                if (this.isCreator()) {
                  Button({ type: ButtonType.Normal }) {
                    Row() {
                      Text('＋')
                        .fontSize(16)
                        .fontColor(AppTheme.accentBlue)
                      Text('邀请')
                        .fontSize(13)
                        .fontColor(AppTheme.textSecondary)
                        .margin({ left: 4 })
                    }
                  }
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    this.showInviteDialog = true;
                    this.invitePhone = '';
                  })

                  Button({ type: ButtonType.Circle }) {
                    Text('···')
                      .fontSize(18)
                      .fontColor(AppTheme.textSecondary)
                  }
                  .width(40)
                  .height(40)
                  .backgroundColor(Color.Transparent)
                  .margin({ left: 6 })
                  .onClick(() => {
                    this.showMoreDialog = true;
                    this.confirmDelete = false;
                  })
                }
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 6, bottom: 10 })

            // 成员卡片列表
            List() {
              ForEach((this.currentGroup as FamilyGroup).members, (m: GroupMember) => {
                ListItem() {
                  Row() {
                    // 左侧头像块
                    Row() {
                      Text(this.memberLetter(m))
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(AppTheme.brandBlue)
                    }
                    .width(56)
                    .height(56)
                    .justifyContent(FlexAlign.Center)   // 水平居中
                    .alignItems(VerticalAlign.Center)   // 垂直居中
                    .borderRadius(12)
                    .backgroundColor('#EAF2FF')

                    Column() {
                      Text(this.memberName(m))
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(AppTheme.textPrimary)
                      Text(this.memberSubtitle(m))
                        .fontSize(12)
                        .fontColor(AppTheme.textSecondary)
                        .margin({ top: 6 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    .margin({ left: 12 })

                    // 电话按钮（占位）
                    Button({ type: ButtonType.Circle }) {
                      Text('📞')
                        .fontSize(16)
                        .fontColor('#2E7D32')
                    }
                    .width(44)
                    .height(44)
                    .backgroundColor('#E8F5E9')
                    .margin({ right: 10 })

                    // 右侧开关（占位）
                    Toggle({ type: ToggleType.Switch, isOn: true })
                      .selectedColor(AppTheme.accentBlue)
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor(Color.White)
                  .borderRadius(18)
                  .shadow({ radius: 10, color: '#00000010', offsetY: 2 })
                }
                .margin({ bottom: 12 })
              })
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 16, right: 16, bottom: 90 })
          }
        }
        .width('100%')
        .layoutWeight(1)

        MainBottomNav({ currentIndex: 1 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.pageBg)

      // 底部主按钮：创建家庭组（与截图一致）
      Button('＋ 创建家庭组')
        .width('86%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(AppTheme.accentBlue)
        .borderRadius(26)
        .position({ x: '7%', y: '84%' })
        .onClick(() => { this.showCreateDialog = true; })

      // 邀请成员弹窗（仅创建者）
      if (this.showInviteDialog) {
        Column() {
          Text('邀请成员')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.textPrimary)
            .width('100%')
          Text('将向对方发送邀请，对方同意后加入家庭组。')
            .fontSize(13)
            .fontColor(AppTheme.textSecondary)
            .width('100%')
            .margin({ top: 10, bottom: 16 })
          TextInput({ placeholder: '对方手机号', text: this.invitePhone })
            .type(InputType.PhoneNumber)
            .maxLength(11)
            .onChange((v: string) => { this.invitePhone = v; })
            .width('100%')
            .height(48)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#EEF2F6')
            .borderRadius(10)
            .borderWidth(1)
            .borderColor('#D1D5DB')

          Row() {
            Button('取消')
              .layoutWeight(1)
              .backgroundColor(Color.Transparent)
              .fontColor(AppTheme.textSecondary)
              .onClick(() => { this.showInviteDialog = false; })
            Button('发送邀请')
              .layoutWeight(1)
              .margin({ left: 8 })
              .backgroundColor(AppTheme.accentBlue)
              .fontColor(Color.White)
              .onClick(() => void this.inviteMember())
          }
          .width('100%')
          .margin({ top: 18 })
        }
        .width('86%')
        .padding(22)
        .backgroundColor('#EEF2F6')
        .borderRadius(20)
        .position({ x: '7%', y: '28%' })
      }

      // 更多操作：删除家庭组（仅创建者）
      if (this.showMoreDialog) {
        Column() {
          Button(this.confirmDelete ? '确认删除家庭组' : '删除家庭组')
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontColor('#E53935')
            .backgroundColor(Color.White)
            .borderRadius(14)
            .onClick(() => {
              if (!this.confirmDelete) {
                this.confirmDelete = true;
                return;
              }
              this.showMoreDialog = false;
              this.confirmDelete = false;
              if (this.currentGroup !== null) {
                void this.deleteGroup((this.currentGroup as FamilyGroup).id);
              }
            })
          Button('取消')
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontColor(AppTheme.textPrimary)
            .backgroundColor(Color.White)
            .borderRadius(14)
            .margin({ top: 10 })
            .onClick(() => {
              this.showMoreDialog = false;
              this.confirmDelete = false;
            })
        }
        .width('86%')
        .padding(16)
        .backgroundColor('#00000000')
        .position({ x: '7%', y: '74%' })
      }

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
