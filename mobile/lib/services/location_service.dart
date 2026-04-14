import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/location_api.dart';
import '../app_logger.dart';

/// 与 [AndroidSettings.distanceFilter] 一致：位移不足该米数时系统不向 stream 投递新点。
const int _kMinMoveMetersInt = 5;
const double _kMinMoveMeters = 5.0;

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
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _kMinMoveMetersInt,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '定位共享',
          notificationText: '正在后台持续定位并上传位置',
          notificationChannelName: '定位共享',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _kMinMoveMetersInt,
    );
  }

  Future<Position?> getCurrentPosition() async {
    if (!await requestPermission()) return null;
    return Geolocator.getCurrentPosition(locationSettings: _locationSettings());
  }

  /// 位移不足 [_kMinMoveMeters] 时 [Geolocator.getPositionStream] 不回调；
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

    // 首次单点仅上传（相对无「上次上传」视为有变化）；界面上的 onLocation 仅由 stream 在位移≥5m 时触发
    try {
      final first =
          await Geolocator.getCurrentPosition(locationSettings: settings);
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
