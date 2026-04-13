import { router } from '@kit.ArkUI';
import { HttpClient } from '../api/HttpClient';
import { LocationService } from '../services/LocationService';

interface LocationData {
  user_id: string;
  nickname: string | null;
  longitude: number;
  latitude: number;
}

@Entry
@Component
struct MapPage {
  @State myLat: number = 0;
  @State myLng: number = 0;
  @State familyLocations: LocationData[] = [];
  @State tracking: boolean = false;
  @State currentTab: number = 0;
  private locationService: LocationService = new LocationService();

  aboutToAppear(): void {
    this.loadLocations();
    this.startTracking();
  }

  async loadLocations(): Promise<void> {
    try {
      const res = await HttpClient.get('/location/latest') as Record<string, object>;
      const data = res['data'] as Record<string, number>;
      if (data) {
        this.myLng = data['longitude'] ?? 0;
        this.myLat = data['latitude'] ?? 0;
      }
    } catch (e) {}
  }

  startTracking(): void {
    this.locationService.startContinuousLocation(async (loc) => {
      this.myLng = loc.longitude;
      this.myLat = loc.latitude;
      await this.locationService.uploadLocation(loc.longitude, loc.latitude, loc.altitude);
    });
    this.tracking = true;
  }

  build() {
    Column() {
      Row() {
        Text('定位共享').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
        Button({ type: ButtonType.Circle }) { Image($r('sys.media.ohos_ic_public_refresh')).width(20).height(20) }
          .width(36).height(36)
          .onClick(() => this.loadLocations())
      }.width('100%').padding(16)

      // 地图占位区域
      Stack() {
        Column() {
          Image($r('sys.media.ohos_ic_public_location')).width(48).height(48).fillColor('#2196F3')
          Text('高德地图区域').fontSize(14).fontColor('#999').margin({ top: 8 })
          Text('需配置高德地图鸿蒙 SDK').fontSize(12).fontColor('#ccc')
          if (this.myLng !== 0) {
            Text('经度: ' + this.myLng.toFixed(6)).fontSize(12).margin({ top: 12 })
            Text('纬度: ' + this.myLat.toFixed(6)).fontSize(12)
          }
        }.justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#f0f0f0')

      // 底部导航
      Row() {
        this.navItem('地图', 0, 'pages/MapPage')
        this.navItem('家庭', 1, 'pages/FamilyPage')
        this.navItem('共享', 2, 'pages/SharingPage')
        this.navItem('轨迹', 3, 'pages/TrajectoryPage')
        this.navItem('通知', 4, 'pages/NotificationsPage')
        this.navItem('设置', 5, 'pages/SettingsPage')
      }
      .width('100%')
      .height(56)
      .justifyContent(FlexAlign.SpaceAround)
      .borderWidth({ top: 1 })
      .borderColor('#e0e0e0')
    }
    .width('100%')
    .height('100%')
  }

  @Builder navItem(label: string, idx: number, page: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(this.currentTab === idx ? '#2196F3' : '#999')
    }
    .onClick(() => {
      if (idx !== this.currentTab) {
        router.replaceUrl({ url: page });
      }
    })
    .justifyContent(FlexAlign.Center)
    .height('100%')
  }
}
