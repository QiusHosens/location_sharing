import { router, promptAction } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { HttpClient } from '../api/HttpClient';
import { appendTrajectoryQuery, TrajectoryQueryParams } from '../api/ApiPayloads';
import { ConfigApi, MapConfig } from '../api/ConfigApi';
import { AppTheme } from '../common/AppTheme';

interface TrajectoryPoint {
  longitude: number;
  latitude: number;
  recorded_at?: string;
}

interface TrajectoryResp {
  user_id?: string;
  total?: number;
  points?: TrajectoryPoint[];
}

interface TrajectoryCoord {
  lng: number;
  lat: number;
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

function fmtHm(iso: string | undefined): string {
  if (!iso || iso.length === 0) {
    return '';
  }
  const t = iso.indexOf('T');
  if (t >= 0) {
    const part = iso.substring(t + 1);
    if (part.length >= 5) {
      return part.substring(0, 5);
    }
  }
  return iso;
}

@Entry
@Component
struct TrajectoryDetailPage {
  @State title: string = '轨迹详情';
  @State userId: string = '';
  @State startIso: string = '';
  @State endIso: string = '';

  @State useOptimized: boolean = true;
  @State loading: boolean = false;
  @State points: TrajectoryPoint[] = [];
  @State mapLoading: boolean = true;
  @State mapError: string = '';
  @State webPageLoaded: boolean = false;

  private webController: webview.WebviewController = new webview.WebviewController();
  private mapCfg: MapConfig | null = null;
  private mapBridge: MapBridge = new MapBridge();

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string> | undefined;
    if (p) {
      this.title = p['title'] ?? this.title;
      this.userId = p['user_id'] ?? '';
      this.startIso = p['start_time'] ?? '';
      this.endIso = p['end_time'] ?? '';
    }
    HttpClient.setContext(getContext(this));
    // 绑定 H5 回调（arkts-no-untyped-obj-literals 要求显式 class/interface）
    this.mapBridge.onReadyCb = () => {
      this.mapLoading = false;
      this.mapError = '';
      void this.syncTrajectoryToMap();
    };
    this.mapBridge.onErrorCb = (msg: string) => {
      this.mapLoading = false;
      this.mapError = msg;
    };
    void this.loadPoints();
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
      // 初始化地图（加载 AMap JS），成功后 H5 会回调 MapBridge.onReady
      await this.webController.runJavaScript(
        `window.LSTrajectoryMap && window.LSTrajectoryMap.init(${JSON.stringify(key)}, ${JSON.stringify(secret)});`
      );
    } catch {
      // ignore
    }
  }

  async loadPoints(): Promise<void> {
    if (this.userId.length === 0 || this.startIso.length === 0 || this.endIso.length === 0) {
      this.points = [];
      void this.syncTrajectoryToMap();
      return;
    }
    this.loading = true;
    try {
      const q: TrajectoryQueryParams = { user_id: this.userId, start_time: this.startIso, end_time: this.endIso };
      const path = appendTrajectoryQuery(this.useOptimized ? '/trajectory/optimized' : '/trajectory', q);
      const res = await HttpClient.get(path) as Record<string, object>;
      const data = res['data'] as TrajectoryResp;
      this.points = (data.points ?? []) as TrajectoryPoint[];
      void this.syncTrajectoryToMap();
    } catch {
      this.points = [];
      promptAction.showToast({ message: '加载失败' });
    }
    this.loading = false;
  }

  trajectoryPayloadJson(): string {
    // 注意：后端是 WGS84，经纬度直接传到 JS 侧（可在 JS 侧或后端统一做 GCJ02，这里与 mobile 一致先不转换）
    const list: TrajectoryCoord[] = this.points.map((p: TrajectoryPoint) => {
      const c: TrajectoryCoord = { lng: p.longitude, lat: p.latitude };
      return c;
    });
    return JSON.stringify(list);
  }

  async syncTrajectoryToMap(): Promise<void> {
    try {
      const json = this.trajectoryPayloadJson();
      await this.webController.runJavaScript(
        `window.LSTrajectoryMap && window.LSTrajectoryMap.setTrajectory(${json});`
      );
    } catch {
      /* ignore */
    }
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('‹').fontSize(22).fontColor(AppTheme.textPrimary)
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())

        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row() {
          Text('原始').fontSize(12).fontColor(AppTheme.textSecondary)
          Toggle({ type: ToggleType.Switch, isOn: this.useOptimized })
            .margin({ left: 6, right: 6 })
            .selectedColor(AppTheme.accentBlue)
            .onChange((v: boolean) => {
              if (this.loading) {
                return;
              }
              this.useOptimized = v;
              void this.loadPoints();
            })
          Text('优化').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.accentBlue)
        }
        .margin({ right: 8 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(Color.White)
      .borderWidth({ bottom: 1 })
      .borderColor(AppTheme.border)

      // 地图（JS API），先拉 key/secret 再加载；轨迹点变化只注入 setTrajectory，不重载页面
      Stack() {
        Web({ src: $rawfile('trajectory_map.html'), controller: this.webController })
          .width('100%')
          .height('100%')
          .onPageEnd(() => {
            this.webPageLoaded = true;
            void this.ensureMapInited();
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

        // 顶部信息条
        Row() {
          Text('共 ' + this.points.length + ' 点')
            .fontSize(12)
            .fontColor(Color.White)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#66000000')
            .borderRadius(14)
          Text((this.useOptimized ? '优化' : '原始') + '数据')
            .fontSize(12)
            .fontColor(this.useOptimized ? AppTheme.accentBlue : Color.White)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#66000000')
            .borderRadius(14)
            .margin({ left: 8 })
        }
        .margin({ left: 12, top: 12 })
        .align(Alignment.TopStart)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBg)
  }
}

