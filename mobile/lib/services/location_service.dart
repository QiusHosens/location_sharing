import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/location_api.dart';
import '../app_logger.dart';

class LocationService {
  final LocationApi _api = LocationApi();
  StreamSubscription<Position>? _subscription;
  Timer? _uploadTimer;

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
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
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
      distanceFilter: 5,
    );
  }

  Future<Position?> getCurrentPosition() async {
    if (!await requestPermission()) return null;
    return Geolocator.getCurrentPosition(locationSettings: _locationSettings());
  }

  /// 启动后进入后台会显示系统通知（前台服务），便于持续定位与上传。
  Future<bool> startTracking({int intervalSeconds = 5, Function(Position)? onLocation}) async {
    if (!await requestPermission()) return false;

    _subscription?.cancel();
    _uploadTimer?.cancel();

    final settings = _locationSettings();
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen((position) {
      onLocation?.call(position);
    });

    _uploadTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(locationSettings: settings);
        await _api.uploadLocation(
          longitude: pos.longitude,
          latitude: pos.latitude,
          altitude: pos.altitude,
          speed: pos.speed,
          bearing: pos.heading,
          accuracy: pos.accuracy,
          source: 'gps',
        );
      } catch (e, st) {
        appLogger.e('Upload location error', error: e, stackTrace: st);
      }
    });
    return true;
  }

  void stopTracking() {
    _subscription?.cancel();
    _uploadTimer?.cancel();
    _subscription = null;
    _uploadTimer = null;
  }
}
