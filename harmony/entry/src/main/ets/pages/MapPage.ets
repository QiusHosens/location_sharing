import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { webview } from '@kit.ArkWeb';
import { HttpClient } from '../api/HttpClient';
import { ConfigApi, MapConfig } from '../api/ConfigApi';
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

interface JsMePayload {
  lng: number;
  lat: number;
  letter: string;
  label: string;
  color: string;
}

interface JsFamilyPayload {
  id: string;
  lng: number;
  lat: number;
  letter: string;
  label: string;
  color: string;
}

class MapBridge {
  onReadyCb: (() => void) | null = null;
  onErrorCb: ((msg: string) => void) | null = null;

  onReady(): void {
    if (this.onReadyCb) {
      this.onReadyCb();
    }
  }

  onError(msg: string): void {
    if (this.onErrorCb) {
      this.onErrorCb(msg);
    }
  }
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
  @State mapLoading: boolean = true;
  @State mapError: string = '';
  @State webPageLoaded: boolean = false;
  // 家人状态抽屉：0=展开，越大越向下隐藏（默认完全隐藏）
  @State familySheetOffset: number = 0;
  private locationService: LocationService = new LocationService();

  private webController: webview.WebviewController = new webview.WebviewController();
  private mapBridge: MapBridge = new MapBridge();
  private mapCfg: MapConfig | null = null;

  private readonly sheetHeight: number = 340;
  private readonly sheetHeaderHeight: number = 86;
  private readonly navHeight: number = 60;
  private readonly fabSize: number = 52;

  aboutToAppear(): void {
    HttpClient.setContext(getContext(this));
    void this.initHeader();
    void this.loadLocations();
    this.startTracking();

    this.mapBridge.onReadyCb = () => {
      this.mapLoading = false;
      this.mapError = '';
      void this.syncAllToMap(false);
    };
    this.mapBridge.onErrorCb = (msg: string) => {
      this.mapLoading = false;
      this.mapError = msg;
    };

    // 默认不展示家人状态（完全隐藏）
    this.familySheetOffset = this.sheetHeight;
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
              const r: FamilyLocRow = {
                user_id: uid,
                nickname: nick,
                longitude: toNum(row['longitude'] as number | string | undefined),
                latitude: toNum(row['latitude'] as number | string | undefined),
                recorded_at: row['recorded_at'] !== undefined ? row['recorded_at'].toString() : undefined,
                battery_level: toInt(row['battery_level'] as number | string | undefined),
              };
              collected.push(r);
            }
          } catch {
            /* ignore */
          }
        }
      }
      this.familyLocations = dedupeFamilyRows(collected);
      void this.syncFamilyToMap();
    } catch {
      /* ignore */
    }
  }

  startTracking(): void {
    const ok = this.locationService.startContinuousLocation(async (loc) => {
      this.myLng = loc.longitude;
      this.myLat = loc.latitude;
      await this.locationService.uploadLocation(loc.longitude, loc.latitude, loc.altitude);
      void this.syncMeToMap();
    });
    if (!ok) {
      promptAction.showToast({ message: '请先在系统设置中打开「定位服务」，再使用位置共享' });
    }
  }

  async initMapConfig(): Promise<void> {
    this.mapLoading = true;
    this.mapError = '';
    try {
      const cfg = await ConfigApi.getMapConfig(false);
      this.mapCfg = cfg;
      await this.ensureMapInited();
    } catch {
      this.mapError = '地图配置加载失败';
      this.mapLoading = false;
    }
  }

  async ensureMapInited(): Promise<void> {
    if (!this.webPageLoaded) {
      return;
    }
    if (!this.mapCfg) {
      await this.initMapConfig();
      return;
    }
    const key = this.mapCfg.web_key ?? '';
    const secret = this.mapCfg.web_security_secret ?? '';
    try {
      await this.webController.runJavaScript(
        `window.LSMap && window.LSMap.init(${JSON.stringify(key)}, ${JSON.stringify(secret)});`
      );
    } catch {
      /* ignore */
    }
  }

  mePayload(): JsMePayload {
    const p: JsMePayload = {
      lng: this.myLng,
      lat: this.myLat,
      letter: this.headerLetter,
      label: '我',
      color: AppTheme.accentBlue,
    };
    return p;
  }

  familyPayload(): JsFamilyPayload[] {
    const out: JsFamilyPayload[] = [];
    const len = this.familyLocations.length;
    for (let i = 0; i < len; i++) {
      const m = this.familyLocations[i];
      const letter = m.nickname.length > 0 ? m.nickname.substring(0, 1).toUpperCase() : '?';
      const label = m.nickname.length > 0 ? m.nickname : '家人';
      const tone = rowToneIndex(m.user_id);
      const color = tone === 0 ? AppTheme.brandBlue : AppTheme.accentBlue;
      const item: JsFamilyPayload = {
        id: m.user_id,
        lng: m.longitude,
        lat: m.latitude,
        letter: letter,
        label: label,
        color: color,
      };
      out.push(item);
    }
    return out;
  }

  async syncMeToMap(): Promise<void> {
    if (!this.webPageLoaded) return;
    try {
      const json = JSON.stringify(this.mePayload());
      await this.webController.runJavaScript(`window.LSMap && window.LSMap.setMe(${json});`);
    } catch {
      /* ignore */
    }
  }

  async syncFamilyToMap(): Promise<void> {
    if (!this.webPageLoaded) return;
    try {
      const json = JSON.stringify(this.familyPayload());
      await this.webController.runJavaScript(`window.LSMap && window.LSMap.setFamily(${json});`);
    } catch {
      /* ignore */
    }
  }

  async syncAllToMap(fit: boolean): Promise<void> {
    await this.syncMeToMap();
    await this.syncFamilyToMap();
    if (fit) {
      try {
        await this.webController.runJavaScript(`window.LSMap && window.LSMap.fitToAll && window.LSMap.fitToAll();`);
      } catch {
        /* ignore */
      }
    }
  }

  async centerToMe(): Promise<void> {
    if (!this.webPageLoaded) return;
    try {
      await this.webController.runJavaScript(`window.LSMap && window.LSMap.centerToMe && window.LSMap.centerToMe();`);
    } catch {
      /* ignore */
    }
  }

  toggleFamilySheet(): void {
    const hiddenOffset = this.sheetHeight;
    this.familySheetOffset = this.familySheetOffset >= hiddenOffset ? 0 : hiddenOffset;
  }

  onNavTap(): void {
    promptAction.showToast({ message: '导航将使用系统地图打开' });
  }

  build() {
    Column() {
      Stack() {
        // 地图底层（JS API），页面常驻；key/secret 通过后端 /config/map 获取并缓存
        Web({ src: $rawfile('map_page.html'), controller: this.webController })
          .width('100%')
          .height('100%')
          .onPageEnd(() => {
            this.webPageLoaded = true;
            void this.initMapConfig();
          })
          .javaScriptProxy({
            object: this.mapBridge,
            name: 'MapBridge',
            methodList: ['onReady', 'onError'],
            controller: this.webController
          })

        if (this.mapError.length > 0) {
          Column() {
            Text(this.mapError).fontSize(14).fontColor(Color.White)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#66000000')
        } else if (this.mapLoading) {
          Column() {
            LoadingProgress().width(32).height(32)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#33000000')
        }

        // 右下角悬浮按钮：定位 / 列表（用全屏容器定位，避免跑到中间）
        Row() {
          Column() {
            Button({ type: ButtonType.Circle }) {
              Text('◎')
                .fontSize(20)
                .fontColor(Color.White)
            }
            .width(this.fabSize)
            .height(this.fabSize)
            .backgroundColor(AppTheme.accentBlue)
            .shadow({ radius: 10, color: '#00000022', offsetY: 4 })
            .onClick(() => void this.centerToMe())

            Button({ type: ButtonType.Circle }) {
              Text('≡')
                .fontSize(20)
                .fontColor(Color.White)
            }
            .width(this.fabSize)
            .height(this.fabSize)
            .margin({ top: 12 })
            .backgroundColor(AppTheme.brandBlue)
            .shadow({ radius: 10, color: '#00000022', offsetY: 4 })
            .onClick(() => this.toggleFamilySheet())
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Bottom)
        .padding({ right: 16, bottom: this.navHeight })
        .align(Alignment.BottomStart)

        // 家人状态抽屉（可下拉收起）
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
              .onClick(() => {
                void this.loadLocations();
                void this.syncAllToMap(true);
              })
          }
          .width('100%')
          .padding({ left: 4, right: 4 })

          // 列表区域（抽屉下拉时会被裁剪隐藏）
          Column() {
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
              .height(this.sheetHeight - this.sheetHeaderHeight - 18)
              .width('100%')
              .margin({ top: 4 })
            }
          }
          .width('100%')
          .clip(true)
        }
        .width('100%')
        .height(this.sheetHeight)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 28, topRight: 28 })
        .shadow({ radius: 20, color: '#00000018', offsetY: -4 })
        // 隐藏态必须“不显示且不可点击”：Visibility.None
        .visibility(this.familySheetOffset >= this.sheetHeight ? Visibility.None : Visibility.Visible)
        .translate({ x: 0, y: this.familySheetOffset })
        .gesture(
          PanGesture()
            .onActionUpdate((e) => {
              const maxOffset = this.sheetHeight;
              let next = this.familySheetOffset + (e.offsetY as number);
              if (next < 0) {
                next = 0;
              } else if (next > maxOffset) {
                next = maxOffset;
              }
              this.familySheetOffset = next;
            })
            .onActionEnd(() => {
              const hiddenOffset = this.sheetHeight;
              // 过半就隐藏，否则展开
              this.familySheetOffset = this.familySheetOffset > hiddenOffset * 0.45 ? hiddenOffset : 0;
            })
        )
        .align(Alignment.BottomStart)
      }
      .clip(true)
      .layoutWeight(1)
      .width('100%')

      MainBottomNav({ currentIndex: 0 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
