import { router } from '@kit.ArkUI';
import { HttpClient } from '../api/HttpClient';
import { preferences } from '@kit.ArkData';
import { appendTrajectoryQuery, TrajectoryQueryParams } from '../api/ApiPayloads';

interface TrajectoryPoint {
  longitude: number;
  latitude: number;
  recorded_at: string;
}

/** 与后端 /trajectory 返回 data 结构一致 */
interface TrajectoryDayData {
  points?: TrajectoryPoint[];
  total?: number;
}

@Entry
@Component
struct TrajectoryPage {
  @State points: TrajectoryPoint[] = [];
  @State total: number = 0;
  @State loading: boolean = false;

  async query(): Promise<void> {
    this.loading = true;
    try {
      const store = await preferences.getPreferences(getContext(this), 'auth');
      const userId = await store.get('user_id', '') as string;
      const now = new Date();
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
      const end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59).toISOString();
      const query: TrajectoryQueryParams = {
        user_id: userId,
        start_time: start,
        end_time: end,
      };
      const pathWithQuery = appendTrajectoryQuery('/trajectory', query);
      const res = await HttpClient.get(pathWithQuery) as Record<string, object>;
      const data = res['data'] as TrajectoryDayData;
      this.points = data.points ?? [];
      this.total = data.total ?? 0;
    } catch (e) {}
    this.loading = false;
  }

  aboutToAppear(): void { this.query(); }

  build() {
    Column() {
      Row() {
        Text('历史轨迹').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
        Button('查询今天').height(32).fontSize(12).onClick(() => this.query())
      }.width('100%').padding(16)

      if (this.total > 0) {
        Text('共 ' + this.total + ' 个轨迹点').fontSize(12).fontColor('#999').padding({ left: 16 })
      }

      if (this.points.length === 0) {
        Text('暂无轨迹数据').fontSize(14).fontColor('#999').margin({ top: 64 })
      } else {
        List() {
          ForEach(this.points, (p: TrajectoryPoint, idx: number) => {
            ListItem() {
              Row() {
                Text(String(idx + 1)).fontSize(10).fontColor(Color.White).width(24).height(24).borderRadius(12)
                  .backgroundColor('#2196F3').textAlign(TextAlign.Center)
                Column() {
                  Text('经度: ' + p.longitude.toFixed(6) + '  纬度: ' + p.latitude.toFixed(6)).fontSize(13)
                  Text(p.recorded_at).fontSize(11).fontColor('#999')
                }.margin({ left: 12 }).alignItems(HorizontalAlign.Start)
              }.width('100%').padding(12)
            }
          })
        }.width('100%').layoutWeight(1)
      }

      Row() {
        this.navItem('地图', 'pages/MapPage')
        this.navItem('家庭', 'pages/FamilyPage')
        this.navItem('共享', 'pages/SharingPage')
        this.navItem('轨迹', '')
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
