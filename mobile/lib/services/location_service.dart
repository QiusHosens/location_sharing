import 'dart:async';
import 'dart:math' as math;

import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:permission_handler/permission_handler.dart';

import '../api/location_api.dart';
import '../app_logger.dart';

const double _kMinMoveMeters = 5.0;

const Duration _kOneShotTimeout = Duration(seconds: 20);

/// 存取与高德 SDK 一致为 GCJ-02。
class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.bearing,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? bearing;
  final double? accuracy;
}

bool _useAmapLocation() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

double _distanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _rad(double d) => d * math.pi / 180.0;

double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return null;
}

LocationSnapshot? _snapshotFromAmapMap(Map<String, Object> e) {
  if (e.containsKey('errorCode')) return null;
  final rawLat = _toDouble(e['latitude']);
  final rawLon = _toDouble(e['longitude']);
  if (rawLat == null || rawLon == null) return null;
  return LocationSnapshot(
    latitude: rawLat,
    longitude: rawLon,
    altitude: _toDouble(e['altitude']),
    speed: _toDouble(e['speed']),
    bearing: _toDouble(e['bearing']),
    accuracy: _toDouble(e['accuracy']),
  );
}

AMapLocationOption _trackingOptions() {
  final opt = AMapLocationOption(
    needAddress: false,
    onceLocation: false,
    locationMode: AMapLocationMode.Hight_Accuracy,
    locationInterval: 4000,
    geoLanguage: GeoLanguage.DEFAULT,
    pausesLocationUpdatesAutomatically: false,
    desiredAccuracy: DesiredAccuracy.Best,
  );
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    opt.distanceFilter = _kMinMoveMeters;
  }
  return opt;
}

AMapLocationOption _oneShotOptions() {
  final opt = AMapLocationOption(
    needAddress: false,
    onceLocation: true,
    locationMode: AMapLocationMode.Hight_Accuracy,
    locationInterval: 1000,
    geoLanguage: GeoLanguage.DEFAULT,
    pausesLocationUpdatesAutomatically: false,
    desiredAccuracy: DesiredAccuracy.Best,
  );
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    opt.distanceFilter = -1;
  }
  return opt;
}

class LocationService {
  final LocationApi _api = LocationApi();
  final Battery _battery = Battery();

  AMapFlutterLocation? _trackingPlugin;
  StreamSubscription<Map<String, Object>>? _subscription;
  LocationSnapshot? _lastUploaded;
  LocationSnapshot? _lastUiEmitted;

  /// 前台 + 申请「始终允许」以便后台持续定位（Android 10+）
  Future<bool> requestPermission() async {
    var base = await Permission.location.request();
    if (!base.isGranted) return false;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final always = await Permission.locationAlways.status;
      if (!always.isGranted) {
        final req = await Permission.locationAlways.request();
        if (!req.isGranted) {
          appLogger.w('未授予「始终允许」定位，后台/熄屏时可能被系统限制');
        }
      }
    }
    return true;
  }

  Future<LocationSnapshot?> _oneShotPosition() async {
    if (!_useAmapLocation()) return null;

    final plugin = AMapFlutterLocation();
    final completer = Completer<LocationSnapshot?>();

    late final StreamSubscription<Map<String, Object>> sub;
    sub = plugin.onLocationChanged().listen((Map<String, Object> e) {
      final snap = _snapshotFromAmapMap(e);
      if (snap != null) {
        if (!completer.isCompleted) completer.complete(snap);
      } else if (e.containsKey('errorCode')) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    plugin.setLocationOption(_oneShotOptions());
    plugin.startLocation();

    LocationSnapshot? result;
    try {
      result = await completer.future.timeout(
        _kOneShotTimeout,
        onTimeout: () => null,
      );
    } finally {
      await sub.cancel();
      plugin.stopLocation();
      plugin.destroy();
    }
    return result;
  }

  Future<LocationSnapshot?> getCurrentPosition() async {
    if (!_useAmapLocation()) return null;
    if (!await requestPermission()) return null;
    return _oneShotPosition();
  }

  /// 连续定位：单次结果先上传（与原先 Geolocator 首次 [getCurrentPosition] 一致），
  /// 再由流更新界面；位移不足 [_kMinMoveMeters] 时不上传、不刷新 UI（iOS 可叠加 SDK distanceFilter）。
  Future<bool> startTracking({Function(LocationSnapshot)? onLocation}) async {
    if (!_useAmapLocation()) return false;
    if (!await requestPermission()) return false;

    await stopTracking();

    _lastUploaded = null;
    _lastUiEmitted = null;

    Future<void> maybeUpload(LocationSnapshot pos) async {
      if (_lastUploaded != null) {
        final d = _distanceMeters(
          _lastUploaded!.latitude,
          _lastUploaded!.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (d < _kMinMoveMeters) return;
      }
      try {
        int? batt;
        try {
          batt = await _battery.batteryLevel;
        } catch (_) {}
        await _api.uploadLocation(
          longitude: pos.longitude,
          latitude: pos.latitude,
          altitude: pos.altitude,
          speed: pos.speed,
          bearing: pos.bearing,
          accuracy: pos.accuracy,
          source: 'amap',
          batteryLevel: batt,
        );
        _lastUploaded = pos;
      } catch (e, st) {
        appLogger.e('Upload location error', error: e, stackTrace: st);
      }
    }

    try {
      final first = await _oneShotPosition();
      if (first != null) {
        await maybeUpload(first);
      }
    } catch (e, st) {
      appLogger.w('首次定位失败', error: e, stackTrace: st);
    }

    _trackingPlugin = AMapFlutterLocation();
    _trackingPlugin!.setLocationOption(_trackingOptions());

    void handleEvent(Map<String, Object> e) {
      final snap = _snapshotFromAmapMap(e);
      if (snap == null) return;

      if (_lastUiEmitted == null) {
        _lastUiEmitted = snap;
        onLocation?.call(snap);
        unawaited(maybeUpload(snap));
        return;
      }

      final moved = _distanceMeters(
        _lastUiEmitted!.latitude,
        _lastUiEmitted!.longitude,
        snap.latitude,
        snap.longitude,
      );
      if (moved < _kMinMoveMeters) return;

      _lastUiEmitted = snap;
      onLocation?.call(snap);
      unawaited(maybeUpload(snap));
    }

    _subscription = _trackingPlugin!.onLocationChanged().listen(handleEvent);
    _trackingPlugin!.startLocation();

    return true;
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    _trackingPlugin?.stopLocation();
    _trackingPlugin?.destroy();
    _trackingPlugin = null;
    _lastUploaded = null;
    _lastUiEmitted = null;
  }
}
