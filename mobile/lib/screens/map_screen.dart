import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/config_api.dart';
import '../api/location_api.dart';
import '../api/user_api.dart';
import '../services/location_service.dart';
import '../services/mqtt_service.dart';
import '../providers/auth_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final LocationService _locationService = LocationService();
  final MqttService _mqttService = MqttService();
  final LocationApi _locationApi = LocationApi();
  final UserApi _userApi = UserApi();
  final ConfigApi _configApi = ConfigApi();
  List<Map<String, dynamic>> _familyLocations = [];
  Map<String, dynamic>? _myLocation;
  bool _tracking = false;
  MapConfig? _mapConfig;
  String? _configError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cfg = await _configApi.getMapConfig();
      if (mounted) setState(() => _mapConfig = cfg);
    } catch (e) {
      if (mounted) setState(() => _configError = '无法加载地图配置');
    }
    final auth = ref.read(authProvider);
    if (auth.userId != null) {
      _mqttService.onLocationUpdate = (data) => setState(() {});
      await _mqttService.connect(auth.userId!);
    }
    await _loadLocations();
    _startTracking();
  }

  Future<void> _loadLocations() async {
    try {
      _myLocation = await _locationApi.getLatest();
      final groups = await _userApi.getGroups();
      final locs = <Map<String, dynamic>>[];
      for (final g in groups) {
        try {
          final familyLocs = await _locationApi.getFamilyLocations(g['id']);
          for (final l in familyLocs) locs.add(Map<String, dynamic>.from(l));
        } catch (_) {}
      }
      setState(() => _familyLocations = locs);
    } catch (_) {}
  }

  void _startTracking() {
    _locationService.startTracking(
      intervalSeconds: 5,
      onLocation: (pos) => setState(() {
        _myLocation = {'longitude': pos.longitude, 'latitude': pos.latitude};
      }),
    );
    setState(() => _tracking = true);
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _mapConfig;
    return Scaffold(
      appBar: AppBar(title: const Text('定位共享'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLocations),
      ]),
      body: Stack(children: [
        Container(
          color: Colors.grey[200],
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.map, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text('高德地图区域', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              const SizedBox(height: 4),
              if (_configError != null)
                Text(_configError!, style: const TextStyle(color: Colors.red, fontSize: 12))
              else if (cfg != null && cfg.androidKey.isNotEmpty)
                Text('已加载高德 Key（可接入原生 SDK）', style: TextStyle(color: Colors.grey[600], fontSize: 12))
              else
                Text('请在管理后台配置 amap_android_key', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              if (_myLocation != null) ...[
                const SizedBox(height: 16),
                Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                  const Text('我的位置', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('经度: ${_myLocation!['longitude']}'),
                  Text('纬度: ${_myLocation!['latitude']}'),
                ]))),
              ],
            ]),
          ),
        ),
        if (_familyLocations.isNotEmpty)
          Positioned(top: 8, left: 8, right: 8, child: SizedBox(height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: _familyLocations.map((l) =>
              Padding(padding: const EdgeInsets.only(right: 8), child: Chip(
                avatar: CircleAvatar(child: Text((l['nickname'] ?? '?')[0])),
                label: Text(l['nickname'] ?? '家人'),
              )),
            ).toList()),
          )),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _tracking ? _locationService.stopTracking : _startTracking,
        child: Icon(_tracking ? Icons.gps_fixed : Icons.gps_not_fixed),
      ),
    );
  }
}
