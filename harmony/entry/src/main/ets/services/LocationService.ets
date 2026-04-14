import { geoLocationManager } from '@kit.LocationKit';
import { HttpClient } from '../api/HttpClient';
import { LocationUploadBody } from '../api/ApiPayloads';

export class LocationService {
  private requestId: number = -1;

  async requestPermission(): Promise<boolean> {
    try {
      const isEnabled = geoLocationManager.isLocationEnabled();
      return isEnabled;
    } catch (e) {
      return false;
    }
  }

  async getCurrentLocation(): Promise<geoLocationManager.Location | null> {
    try {
      const request: geoLocationManager.CurrentLocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        scenario: geoLocationManager.LocationRequestScenario.UNSET,
      };
      return await geoLocationManager.getCurrentLocation(request);
    } catch (e) {
      return null;
    }
  }

  /**
   * 注册连续定位。若系统「定位服务」总开关关闭（常见错误码 3301100），返回 false 且不抛错。
   */
  startContinuousLocation(callback: (loc: geoLocationManager.Location) => void): boolean {
    try {
      if (!geoLocationManager.isLocationEnabled()) {
        return false;
      }
      const request: geoLocationManager.LocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        scenario: geoLocationManager.LocationRequestScenario.NAVIGATION,
        timeInterval: 5,
        distanceInterval: 5,
      };
      geoLocationManager.on('locationChange', request, callback);
      return true;
    } catch {
      return false;
    }
  }

  stopContinuousLocation(): void {
    geoLocationManager.off('locationChange');
  }

  async uploadLocation(longitude: number, latitude: number, altitude?: number): Promise<void> {
    const body: LocationUploadBody = altitude !== undefined
      ? { longitude: longitude, latitude: latitude, altitude: altitude, source: 'harmony' }
      : { longitude: longitude, latitude: latitude, source: 'harmony' };
    await HttpClient.post('/location/upload', body);
  }
}
