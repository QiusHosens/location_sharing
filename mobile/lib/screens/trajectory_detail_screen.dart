import 'dart:math' as math;

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../api/location_api.dart';

const AMapPrivacyStatement _amapPrivacy = AMapPrivacyStatement(
  hasContains: true,
  hasShow: true,
  hasAgree: true,
);

const String _kAmapAndroidKey = '75499ac31c1dba8d9ffebc451f5332d3';

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
  List<dynamic> _points = [];
  bool _loading = true;
  String? _error;

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
      final res = await _api.getTrajectory(widget.userId, widget.startIso, widget.endIso);
      if (!mounted) return;
      setState(() {
        _points = res['points'] as List? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    }
  }

  bool get _showAmap {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  CameraPosition _initialCamera() {
    if (_points.isEmpty) {
      return const CameraPosition(target: LatLng(39.909187, 116.397451), zoom: 10);
    }
    final p = _points.first;
    final lat = (p['latitude'] as num).toDouble();
    final lng = (p['longitude'] as num).toDouble();
    return CameraPosition(target: LatLng(lat, lng), zoom: 15);
  }

  Set<Polyline> _polylines() {
    if (_points.length < 2) return {};
    final pts = _points
        .map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()))
        .toList();
    return {
      Polyline(
        points: pts,
        width: 6,
        color: const Color(0xCC1976D2),
      ),
    };
  }

  void _fitMap(AMapController c) {
    if (_points.isEmpty) return;
    if (_points.length == 1) {
      final p = _points.first;
      final lat = (p['latitude'] as num).toDouble();
      final lng = (p['longitude'] as num).toDouble();
      c.moveCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
      return;
    }
    final lats = _points.map((p) => (p['latitude'] as num).toDouble()).toList();
    final lngs = _points.map((p) => (p['longitude'] as num).toDouble()).toList();
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
    c.moveCamera(CameraUpdate.newLatLngBounds(bounds, 48));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontSize: 16))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : !_showAmap
                  ? const Center(child: Text('当前平台不支持高德轨迹地图'))
                  : AMapWidget(
                      privacyStatement: _amapPrivacy,
                      apiKey: const AMapApiKey(androidKey: _kAmapAndroidKey),
                      initialCameraPosition: _initialCamera(),
                      polylines: _polylines(),
                      onMapCreated: _fitMap,
                    ),
    );
  }
}
