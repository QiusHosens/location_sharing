import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/location_api.dart';
import '../api/user_api.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../services/mqtt_service.dart';

/// 高德 SDK 8.1+ 要求首次展示地图前完成隐私合规；三者为 false 会白屏。
/// 正式上架前应在隐私弹窗取得用户同意后再设为 true。
const AMapPrivacyStatement _amapPrivacy = AMapPrivacyStatement(
  hasContains: true,
  hasShow: true,
  hasAgree: true,
);

/// 高德 Android Key（客户端内置，不请求后台）
const String _kAmapAndroidKey = '75499ac31c1dba8d9ffebc451f5332d3';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final LocationService _locationService = LocationService();
  final MqttService _mqttService = MqttService();
  final LocationApi _locationApi = LocationApi();
  final UserApi _userApi = UserApi();
  List<Map<String, dynamic>> _familyLocations = [];
  Map<String, dynamic>? _myLocation;
  bool _tracking = false;
  AMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = ref.read(authProvider);
    if (auth.userId != null) {
      _mqttService.onLocationUpdate = (data) => setState(() {});
      await _mqttService.connect(auth.userId!);
    }
    await _loadLocations();
    await _startTracking();
  }

  Future<void> _loadLocations() async {
    try {
      _myLocation = await _locationApi.getLatest();
      final groups = await _userApi.getGroups();
      final locs = <Map<String, dynamic>>[];
      for (final g in groups) {
        try {
          final familyLocs = await _locationApi.getFamilyLocations(g['id']);
          for (final l in familyLocs) {
            locs.add(Map<String, dynamic>.from(l));
          }
        } catch (_) {}
      }
      setState(() => _familyLocations = locs);
      WidgetsBinding.instance.addPostFrameCallback((_) => _moveCameraToMyLocation());
    } catch (_) {}
  }

  Future<void> _startTracking() async {
    final ok = await _locationService.startTracking(
      intervalSeconds: 5,
      onLocation: (pos) {
        setState(() {
          _myLocation = {'longitude': pos.longitude, 'latitude': pos.latitude};
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _moveCameraToMyLocation());
      },
    );
    if (mounted) setState(() => _tracking = ok);
  }

  void _stopTracking() {
    _locationService.stopTracking();
    setState(() => _tracking = false);
  }

  void _onMapCreated(AMapController controller) {
    _mapController = controller;
    _moveCameraToMyLocation();
  }

  void _moveCameraToMyLocation() {
    final m = _myLocation;
    final ctrl = _mapController;
    if (m == null || ctrl == null) return;
    final lat = (m['latitude'] as num?)?.toDouble();
    final lng = (m['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    ctrl.moveCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
  }

  CameraPosition _initialCameraPosition() {
    final m = _myLocation;
    if (m != null) {
      final lat = (m['latitude'] as num?)?.toDouble();
      final lng = (m['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return CameraPosition(target: LatLng(lat, lng), zoom: 16);
      }
    }
    return const CameraPosition(
      target: LatLng(39.909187, 116.397451),
      zoom: 10,
    );
  }

  bool get _showAmap {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    for (final l in _familyLocations) {
      final lat = (l['latitude'] as num?)?.toDouble();
      final lng = (l['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final name = l['nickname']?.toString() ?? '家人';
      markers.add(Marker(
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(title: name),
      ));
    }
    return markers;
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showMap = _showAmap;

    return Scaffold(
      appBar: AppBar(title: const Text('定位共享'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLocations),
      ]),
      body: Stack(children: [
        if (showMap)
          Positioned.fill(
            child: AMapWidget(
              privacyStatement: _amapPrivacy,
              apiKey: const AMapApiKey(androidKey: _kAmapAndroidKey),
              initialCameraPosition: _initialCameraPosition(),
              myLocationStyleOptions: MyLocationStyleOptions(true),
              markers: _buildMarkers(),
              onMapCreated: _onMapCreated,
            ),
          )
        else
          Container(
            color: Colors.grey[200],
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      '地图未就绪',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      defaultTargetPlatform == TargetPlatform.iOS
                          ? '当前为 iOS，请配置 iosKey 后使用高德地图'
                          : '当前平台不支持高德地图组件',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_familyLocations.isNotEmpty)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _familyLocations
                    .map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          avatar: CircleAvatar(child: Text((l['nickname'] ?? '?')[0])),
                          label: Text(l['nickname'] ?? '家人'),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        if (_myLocation != null && showMap)
          Positioned(
            bottom: 88,
            left: 8,
            right: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('我的位置', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('经度: ${_myLocation!['longitude']}'),
                    Text('纬度: ${_myLocation!['latitude']}'),
                  ],
                ),
              ),
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _tracking ? _stopTracking : () => _startTracking(),
        child: Icon(_tracking ? Icons.gps_fixed : Icons.gps_not_fixed),
      ),
    );
  }
}
