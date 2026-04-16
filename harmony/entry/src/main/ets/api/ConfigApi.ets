import { HttpClient } from './HttpClient';

export interface MapConfig {
  web_key: string;
  web_security_secret: string;
  android_key: string;
  ios_key: string;
}

/** 拉取高德地图配置，并做内存缓存 */
export class ConfigApi {
  private static cached: MapConfig | null = null;
  private static inflight: Promise<MapConfig> | null = null;

  static async getMapConfig(forceRefresh: boolean = false): Promise<MapConfig> {
    if (!forceRefresh && ConfigApi.cached) {
      return ConfigApi.cached;
    }
    if (!forceRefresh && ConfigApi.inflight) {
      return ConfigApi.inflight;
    }
    ConfigApi.inflight = (async () => {
      const res = await HttpClient.get('/config/map') as Record<string, object>;
      const data = res['data'] as MapConfig;
      ConfigApi.cached = data;
      return data;
    })().finally(() => {
      ConfigApi.inflight = null;
    });
    return ConfigApi.inflight;
  }
}

