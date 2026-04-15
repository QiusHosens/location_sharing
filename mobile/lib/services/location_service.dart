import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/location_api.dart';
import '../app_logger.dart';

/// 上传阈值：仅当位移达到该距离才上报到服务端。
const double _kMinMoveMeters = 3.0;

class LocationService {
  final LocationApi _api = LocationApi();
  final Battery _battery = Battery();
  StreamSubscription<Position>? _subscription;
  Position? _lastUploaded;

  /// 前台 + 申请「始终允许」以便后台持续定位（Android 10+）
  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

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

  LocationSettings _locationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // 持续获取当前位置用于地图刷新；上传阈值在 maybeUpload 内单独控制。
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: kDebugMode
            ? null
            : const ForegroundNotificationConfig(
                notificationTitle: '定位共享',
                notificationText: '正在后台持续定位并上传位置',
                notificationChannelName: '定位共享',
                enableWakeLock: true,
              ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  /// 单次定位：有历史定位时快速超时（3s），无历史定位时给更长等待（30s）。
  LocationSettings _singleShotSettings(Duration timeout) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: timeout,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      timeLimit: timeout,
    );
  }

  Future<Position?> getCurrentPosition() async {
    if (!await requestPermission()) return null;
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    final timeout = lastKnown != null
        ? const Duration(seconds: 3)
        : const Duration(seconds: 30);
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _singleShotSettings(timeout),
      );
    } on TimeoutException catch (e, st) {
      appLogger.w(
        '单次定位超时（${timeout.inSeconds}s），回退最近一次定位',
        error: e,
        stackTrace: st,
      );
      return lastKnown;
    } catch (e, st) {
      appLogger.w('单次定位失败，回退最近一次定位', error: e, stackTrace: st);
      return lastKnown;
    }
  }

  /// 仅返回最近一次系统缓存定位，不主动发起新定位请求。
  Future<Position?> getLastKnownPosition() async {
    if (!await requestPermission()) return null;
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e, st) {
      appLogger.w('获取最近定位失败', error: e, stackTrace: st);
      return null;
    }
  }

  /// 持续监听系统定位流并回调 [onLocation] 刷新地图；
  /// 上传仅在相对「上次成功上传」位移 ≥ [_kMinMoveMeters] 时执行（含首次无基准点的一次上传）。
  Future<bool> startTracking({Function(Position)? onLocation}) async {
    if (!await requestPermission()) return false;

    _subscription?.cancel();
    _lastUploaded = null;

    final settings = _locationSettings();

    Future<void> maybeUpload(Position pos) async {
      if (_lastUploaded != null) {
        final d = Geolocator.distanceBetween(
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
          bearing: pos.heading,
          accuracy: pos.accuracy,
          source: 'gps',
          batteryLevel: batt,
        );
        _lastUploaded = pos;
      } catch (e, st) {
        appLogger.e('Upload location error', error: e, stackTrace: st);
      }
    }

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
          onLocation?.call(position);
          unawaited(maybeUpload(position));
        });

    // 首次尽快拿到一个可用点，提升首屏体验。
    try {
      final first = await getCurrentPosition();
      if (first == null) return true;
      onLocation?.call(first);
      await maybeUpload(first);
    } catch (e, st) {
      appLogger.w('首次定位失败', error: e, stackTrace: st);
    }

    return true;
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _lastUploaded = null;
  }
}
