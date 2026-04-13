import 'package:flutter/material.dart';
import '../api/location_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrajectoryScreen extends StatefulWidget {
  const TrajectoryScreen({super.key});
  @override State<TrajectoryScreen> createState() => _TrajectoryScreenState();
}

class _TrajectoryScreenState extends State<TrajectoryScreen> {
  final LocationApi _api = LocationApi();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<dynamic> _points = [];
  int _total = 0;
  bool _loading = false;

  Future<void> _query() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final res = await _api.getTrajectory(userId,
        DateTime(_startDate.year, _startDate.month, _startDate.day).toUtc().toIso8601String(),
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toUtc().toIso8601String());
      setState(() { _points = res['points'] ?? []; _total = res['total'] ?? 0; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('查询失败')));
    } finally { setState(() => _loading = false); }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(context: context, initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now());
    if (picked != null) setState(() { if (isStart) _startDate = picked; else _endDate = picked; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史轨迹')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('\/\'),
            onPressed: () => _pickDate(true))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('至')),
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('\/\'),
            onPressed: () => _pickDate(false))),
          const SizedBox(width: 8),
          FilledButton(onPressed: _loading ? null : _query, child: _loading ? const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('查询')),
        ])),
        if (_total > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('共 \ 个轨迹点', style: Theme.of(context).textTheme.bodySmall)),
        Expanded(child: _points.isEmpty
          ? const Center(child: Text('暂无轨迹数据', style: TextStyle(color: Colors.grey)))
          : ListView.builder(itemCount: _points.length, itemBuilder: (ctx, i) {
              final p = _points[i];
              return ListTile(dense: true,
                leading: CircleAvatar(radius: 14, child: Text('\', style: const TextStyle(fontSize: 10))),
                title: Text('经度: \  纬度: \'),
                subtitle: Text(p['recorded_at'] ?? ''),
              );
            })),
      ]),
    );
  }
}
