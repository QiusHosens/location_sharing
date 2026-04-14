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

/** 高德地图 Key（接入鸿蒙 MapComponent 时使用），前端写死 */
const AMAP_ANDROID_KEY: string = 'f17f663b9f38700e72b4f54b35044c7d';

function batteryHigh(batt: number | undefined, index: number): boolean {
  if (batt !== undefined) {
    return batt >= 50;
  }
  return index % 2 === 0;
}

function rowToneIndex(userId: string): number {
  let n = 0;
  const len = userId.length;
  for (let i = 0; i < len; i++) {
    n += userId.charCodeAt(i);
  }
  return n % 2;
}

@Entry
@Component
struct MapPage {
  @State myLat: number = 0;
  @State myLng: number = 0;
  @State familyLocations: FamilyLocRow[] = [];
  @State headerLetter: string = '?';
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

  onNavTap(): void {
    promptAction.showToast({ message: '导航将使用系统地图打开' });
  }

  build() {
    Column() {
      Stack() {
        Column() {
          Column() {
            Text(this.headerLetter)
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(64)
              .height(64)
              .borderRadius(32)
              .textAlign(TextAlign.Center)
              .backgroundColor(AppTheme.accentBlue)
              .borderWidth(4)
              .borderColor(AppTheme.brandBlue)
            Text('我')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(Color.White)
              .borderRadius(10)
              .margin({ top: 8 })
              .shadow({ radius: 6, color: '#00000018', offsetY: 2 })
            Row() {
              Text('●')
                .fontSize(14)
                .fontColor(AppTheme.accentBlue)
            }
            .margin({ top: 6 })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [['#D6E4F0', 0.0], ['#E8EDF3', 0.45], ['#DCE8F0', 1.0]]
          })
        }
        .width('100%')
        .height('100%')

        Row() {
          Text(this.headerLetter)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
            .width(44)
            .height(44)
            .borderRadius(22)
            .textAlign(TextAlign.Center)
            .backgroundColor('#F0F4F8')
            .borderWidth(1)
            .borderColor('#E5E7EB')
          Text('位置共享')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.textPrimary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Button({ type: ButtonType.Circle }) {
            Text('🔔')
              .fontSize(18)
              .fontColor('#111827')
          }
            .width(44)
            .height(44)
            .backgroundColor(Color.Transparent)
            .onClick(() => router.pushUrl({ url: 'pages/NotificationsPage' }))
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .margin({ left: 16, right: 16, top: 10 })
        .backgroundColor('#FFFFFFF2')
        .borderRadius(28)
        .shadow({ radius: 12, color: '#00000014', offsetY: 4 })
        .align(Alignment.TopStart)

        Column() {
          Row()
            .width(36)
            .height(4)
            .backgroundColor('#D1D5DB')
            .borderRadius(2)
            .margin({ top: 10, bottom: 12 })

          Row() {
            Text('家人状态')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.textPrimary)
              .layoutWeight(1)
            Button({ type: ButtonType.Circle }) {
              Text('↻')
                .fontSize(20)
                .fontColor(AppTheme.textSecondary)
            }
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
              .onClick(() => void this.loadLocations())
          }
          .width('100%')
          .padding({ left: 4, right: 4 })

          if (this.familyLocations.length === 0) {
            Text('暂无家人位置')
              .fontSize(14)
              .fontColor(AppTheme.textSecondary)
              .margin({ top: 20, bottom: 28 })
          } else {
            List() {
              ForEach(this.familyLocations, (m: FamilyLocRow) => {
                ListItem() {
                  Row() {
                    Text(m.nickname.length > 0 ? m.nickname.substring(0, 1) : '?')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Color.White)
                      .width(48)
                      .height(48)
                      .borderRadius(24)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(AppTheme.accentBlue)
                    Column() {
                      Text(m.nickname)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(AppTheme.textPrimary)
                      Row() {
                        Text(batteryHigh(m.battery_level, rowToneIndex(m.user_id)) ? '🏠' : '📍')
                          .fontSize(14)
                          .margin({ right: 4 })
                        Text(batteryHigh(m.battery_level, rowToneIndex(m.user_id)) ?
                          '在家' :
                          ('出行中 · 上次 ' + fmtRecordedAt(m.recorded_at)))
                          .fontSize(13)
                          .fontColor(batteryHigh(m.battery_level, rowToneIndex(m.user_id)) ? '#2E7D32' : AppTheme.textSecondary)
                      }
                      .margin({ top: 6 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    .margin({ left: 12 })

                    Row() {
                      Text('🔋')
                        .fontSize(12)
                      Text(m.battery_level !== undefined ? (m.battery_level + '%') : '—')
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(batteryHigh(m.battery_level, rowToneIndex(m.user_id)) ? '#2E7D32' : '#E65100')
                    }
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .borderRadius(20)
                    .backgroundColor(batteryHigh(m.battery_level, rowToneIndex(m.user_id)) ? '#E8F5E9' : '#FFF3E0')

                    Button({ type: ButtonType.Circle }) {
                      Text('➤')
                        .fontSize(16)
                        .fontColor(Color.White)
                    }
                      .width(44)
                      .height(44)
                      .backgroundColor('#4FC3F7')
                      .onClick(() => {
                        this.onNavTap();
                      })
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 10 })
                }
              })
            }
            .height(220)
            .width('100%')
            .margin({ top: 4 })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 28, topRight: 28 })
        .shadow({ radius: 20, color: '#00000018', offsetY: -4 })
        .align(Alignment.BottomStart)
      }
      .layoutWeight(1)
      .width('100%')

      MainBottomNav({ currentIndex: 0 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
