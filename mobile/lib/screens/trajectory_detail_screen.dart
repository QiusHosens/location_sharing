import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../api/location_api.dart';
import '../utils/coord_transform.dart';

const String _kAmapTileUrlTemplate =
    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=7&x={x}&y={y}&z={z}';
const List<String> _kAmapTileSubdomains = ['1', '2', '3', '4'];

/// 在地图上展示某用户某时段内的全部轨迹点（折线）
class TrajectoryDetailScreen extends StatefulWidget {
  const TrajectoryDetailScreen({
    super.key,
    required this.userId,
    required this.startIso,
    required this.endIso,
    required this.title,
  });

  final String userId;
  final String startIso;
  final String endIso;
  final String title;

  @override
  State<TrajectoryDetailScreen> createState() => _TrajectoryDetailScreenState();
}

class _TrajectoryDetailScreenState extends State<TrajectoryDetailScreen> {
  final LocationApi _api = LocationApi();
  final MapController _mapController = MapController();
  List<dynamic> _points = [];
  bool _loading = true;
  String? _error;
  bool _mapReady = false;

  CoordPoint? _toGcjFromTrajectory(dynamic p) {
    if (p is! Map) return null;
    final lat = (p['latitude'] as num?)?.toDouble();
    final lng = (p['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return wgs84ToGcj02(latitude: lat, longitude: lng);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getTrajectory(
          widget.userId, widget.startIso, widget.endIso);
      if (!mounted) return;
      setState(() {
        _points = res['points'] as List? ?? [];
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMap());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    }
  }

  LatLng _initialCenter() {
    if (_points.isEmpty) {
      return const LatLng(39.909187, 116.397451);
    }
    final gcj = _toGcjFromTrajectory(_points.first);
    if (gcj == null) {
      return const LatLng(39.909187, 116.397451);
    }
    return LatLng(gcj.latitude, gcj.longitude);
  }

  List<LatLng> _polylinePoints() {
    return _points
        .map(_toGcjFromTrajectory)
        .whereType<CoordPoint>()
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
  }

  void _fitMap() {
    if (!_mapReady) return;
    final pts = _polylinePoints();
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _mapController.move(pts.first, 16);
      return;
    }
    final lats = pts.map((p) => p.latitude).toList();
    final lngs = pts.map((p) => p.longitude).toList();
    final bounds = LatLngBounds(
      LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
        maxZoom: 17,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final polylinePoints = _polylinePoints();
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(fontSize: 16))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter(),
                    initialZoom: 15,
                    onMapReady: () {
                      _mapReady = true;
                      _fitMap();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _kAmapTileUrlTemplate,
                      subdomains: _kAmapTileSubdomains,
                      userAgentPackageName: 'com.ls.location_sharing',
                    ),
                    if (polylinePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: polylinePoints,
                            color: const Color(0xCC1976D2),
                            strokeWidth: 6,
                          ),
                        ],
                      ),
                  ],
                ),
    );
  }
}
