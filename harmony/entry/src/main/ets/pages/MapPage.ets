import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { HttpClient } from '../api/HttpClient';
import { LocationService } from '../services/LocationService';
import { MainBottomNav } from '../components/MainBottomNav';
import { AppTheme } from '../common/AppTheme';

interface FamilyLocRow {
  user_id: string;
  nickname: string;
  longitude: number;
  latitude: number;
  recorded_at?: string;
  battery_level?: number;
}

function fmtRecordedAt(iso: string | undefined): string {
  if (!iso || iso.length === 0) {
    return '—';
  }
  const t = iso.indexOf('T');
  if (t >= 0) {
    const part = iso.substring(t + 1);
    if (part.length >= 5) {
      return part.substring(0, 5);
    }
  }
  return '—';
}

function toNum(v: number | string | undefined): number {
  if (v === undefined) {
    return 0;
  }
  if (typeof v === 'number') {
    return v;
  }
  const n = parseFloat(v as string);
  return Number.isNaN(n) ? 0 : n;
}

function toInt(v: number | string | undefined): number | undefined {
  if (v === undefined) {
    return undefined;
  }
  if (typeof v === 'number') {
    return Math.round(v);
  }
  const n = parseInt(v as string, 10);
  return Number.isNaN(n) ? undefined : n;
}

function dedupeFamilyRows(rows: FamilyLocRow[]): FamilyLocRow[] {
  const map = new Map<string, FamilyLocRow>();
  const len = rows.length;
  for (let i = 0; i < len; i++) {
    const l = rows[i];
    const id = l.user_id;
    const cur = map.get(id);
    if (!cur) {
      map.set(id, l);
      continue;
    }
    const t1 = cur.recorded_at ?? '';
    const t2 = l.recorded_at ?? '';
    if (t2 > t1) {
      map.set(id, l);
    }
  }
  const out: FamilyLocRow[] = [];
  map.forEach((v: FamilyLocRow) => {
    out.push(v);
  });
  out.sort((a: FamilyLocRow, b: FamilyLocRow) => a.nickname.localeCompare(b.nickname));
  return out;
}

/** 高德地图 Key，前端写死（不向后台请求） */
const AMAP_ANDROID_KEY: string = 'f17f663b9f38700e72b4f54b35044c7d';

@Entry
@Component
struct MapPage {
  @State myLat: number = 0;
  @State myLng: number = 0;
  @State familyLocations: FamilyLocRow[] = [];
  @State headerLetter: string = '?';
  @State showFamilyPanel: boolean = false;
  private locationService: LocationService = new LocationService();

  aboutToAppear(): void {
    HttpClient.setContext(getContext(this));
    void this.initHeader();
    void this.loadLocations();
    this.startTracking();
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

  async loadLocations(): Promise<void> {
    try {
      const latest = await HttpClient.get('/location/latest') as Record<string, object>;
      const loc = latest['data'] as Record<string, number | string>;
      if (loc) {
        this.myLng = toNum(loc['longitude']);
        this.myLat = toNum(loc['latitude']);
      }

      const groupsRes = await HttpClient.get('/groups') as Record<string, object>;
      const rawGroups = groupsRes['data'];
      const collected: FamilyLocRow[] = [];
      if (rawGroups !== undefined && rawGroups !== null) {
        const gArr = rawGroups as Array<Record<string, string>>;
        const glen = gArr.length;
        for (let gi = 0; gi < glen; gi++) {
          const g = gArr[gi];
          const gid = g['id'];
          if (gid === undefined || gid.length === 0) {
            continue;
          }
          try {
            const fam = await HttpClient.get('/location/family/' + gid) as Record<string, object>;
            const rawLocs = fam['data'];
            if (rawLocs === undefined || rawLocs === null) {
              continue;
            }
            const locArr = rawLocs as Array<Record<string, string | number>>;
            const llen = locArr.length;
            for (let li = 0; li < llen; li++) {
              const row = locArr[li];
              const uid = row['user_id']?.toString() ?? '';
              if (uid.length === 0) {
                continue;
              }
              const nickRaw = row['nickname'];
              const nick = nickRaw !== undefined && nickRaw !== null ? nickRaw.toString() : '家人';
              collected.push({
                user_id: uid,
                nickname: nick,
                longitude: toNum(row['longitude'] as number | string | undefined),
                latitude: toNum(row['latitude'] as number | string | undefined),
                recorded_at: row['recorded_at'] !== undefined ? row['recorded_at'].toString() : undefined,
                battery_level: toInt(row['battery_level'] as number | string | undefined),
              });
            }
          } catch {
            /* ignore */
          }
        }
      }
      this.familyLocations = dedupeFamilyRows(collected);
    } catch {
      /* ignore */
    }
  }

  startTracking(): void {
    const ok = this.locationService.startContinuousLocation(async (loc) => {
      this.myLng = loc.longitude;
      this.myLat = loc.latitude;
      await this.locationService.uploadLocation(loc.longitude, loc.latitude, loc.altitude);
    });
    if (!ok) {
      promptAction.showToast({ message: '请先在系统设置中打开「定位服务」，再使用位置共享' });
    }
  }

  batteryGreen(batt: number | undefined, index: number): boolean {
    if (batt !== undefined) {
      return batt >= 50;
    }
    return index % 2 === 0;
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text(this.headerLetter)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.brandBlue)
            .width(40)
            .height(40)
            .borderRadius(20)
            .textAlign(TextAlign.Center)
            .backgroundColor('#E3F2FD')
          Text('位置共享')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Button({ type: ButtonType.Circle }) {
            Text('🔔').fontSize(16)
          }
            .width(40)
            .height(40)
            .backgroundColor(Color.Transparent)
            .onClick(() => router.pushUrl({ url: 'pages/NotificationsPage' }))
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .backgroundColor('#FFFFFFF2')
        .borderRadius(28)
        .margin({ left: 12, right: 12, top: 8 })
      }

      Stack() {
        Column() {
          Text('⌖').fontSize(40).fontColor(AppTheme.brandBlue)
          Text('地图区域').fontSize(14).fontColor(AppTheme.textSecondary).margin({ top: 8 })
          Text('高德 Key 已配置，可接入鸿蒙地图 SDK')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .margin({ top: 4 })
          if (this.myLng !== 0) {
            Text('经度 ' + this.myLng.toFixed(6) + '  纬度 ' + this.myLat.toFixed(6))
              .fontSize(12)
              .fontColor(AppTheme.textSecondary)
              .margin({ top: 12 })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#E8EDF3')

        Column() {
          Blank()
          Column() {
            Button({ type: ButtonType.Circle }) {
              Text('⊙').fontSize(18).fontColor(AppTheme.brandBlue)
            }
              .width(48)
              .height(48)
              .backgroundColor(Color.White)
              .onClick(() => void this.loadLocations())
            Button({ type: ButtonType.Circle }) {
              Text('☰').fontSize(18).fontColor(AppTheme.brandBlue)
            }
              .width(48)
              .height(48)
              .backgroundColor(Color.White)
              .margin({ top: 12 })
              .onClick(() => { this.showFamilyPanel = !this.showFamilyPanel; })
          }
          .alignItems(HorizontalAlign.End)
          .margin({ right: 16, bottom: 16 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
      .layoutWeight(1)

      if (this.showFamilyPanel) {
        Column() {
          Row()
            .width(40)
            .height(4)
            .backgroundColor('#CCCCCC')
            .borderRadius(2)
            .margin({ top: 8, bottom: 8 })
          Row() {
            Text('家人状态')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .layoutWeight(1)
            Button({ type: ButtonType.Circle }) {
              Text('↻').fontSize(18)
            }
              .width(36)
              .height(36)
              .backgroundColor(Color.Transparent)
              .onClick(() => void this.loadLocations())
          }
          .width('100%')
          .padding({ left: 16, right: 8 })

          if (this.familyLocations.length === 0) {
            Text('暂无家人位置')
              .fontSize(14)
              .fontColor(AppTheme.textSecondary)
              .margin({ top: 24, bottom: 24 })
          } else {
            List() {
              ForEach(this.familyLocations, (m: FamilyLocRow, idx: number) => {
                ListItem() {
                  Row() {
                    Text(m.nickname.length > 0 ? m.nickname.substring(0, 1) : '?')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.brandBlue)
                      .width(48)
                      .height(48)
                      .borderRadius(24)
                      .textAlign(TextAlign.Center)
                      .backgroundColor('#E3F2FD')
                    Column() {
                      Text(m.nickname)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppTheme.textPrimary)
                      Row() {
                        Text('上次更新 ' + fmtRecordedAt(m.recorded_at))
                          .fontSize(13)
                          .fontColor(AppTheme.textSecondary)
                      }.margin({ top: 4 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    .margin({ left: 12 })

                    Text(m.battery_level !== undefined ? (m.battery_level + '%') : '—')
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.batteryGreen(m.battery_level, idx) ? '#2E7D32' : '#E65100')
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .borderRadius(20)
                      .backgroundColor(this.batteryGreen(m.battery_level, idx) ? '#E8F5E9' : '#FFF3E0')

                    Button({ type: ButtonType.Circle }) {
                      Text('➤').fontSize(16).fontColor(Color.White)
                    }
                      .width(44)
                      .height(44)
                      .backgroundColor(AppTheme.brandBlue)
                      .onClick(() => {
                        this.showFamilyPanel = false;
                      })
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8, left: 16, right: 16 })
                }
              })
            }
            .height(280)
            .width('100%')
          }
        }
        .width('100%')
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 24, topRight: 24 })
      }

      MainBottomNav({ currentIndex: 0 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
