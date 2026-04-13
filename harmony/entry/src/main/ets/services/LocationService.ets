import { geoLocationManager } from '@kit.LocationKit';
import { HttpClient } from '../api/HttpClient';

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

  startContinuousLocation(callback: (loc: geoLocationManager.Location) => void): void {
    const request: geoLocationManager.LocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
      scenario: geoLocationManager.LocationRequestScenario.NAVIGATION,
      timeInterval: 5,
      distanceInterval: 5,
    };
    geoLocationManager.on('locationChange', request, callback);
  }

  stopContinuousLocation(): void {
    geoLocationManager.off('locationChange');
  }

  async uploadLocation(longitude: number, latitude: number, altitude?: number): Promise<void> {
    await HttpClient.post('/location/upload', {
      longitude, latitude,
      altitude: altitude ?? undefined,
      source: 'harmony',
    });
  }
}
