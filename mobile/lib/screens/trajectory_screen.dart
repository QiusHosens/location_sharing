import 'package:flutter/material.dart';

import '../api/location_api.dart';
import 'trajectory_detail_screen.dart';

class TrajectoryScreen extends StatefulWidget {
  const TrajectoryScreen({super.key});
  @override State<TrajectoryScreen> createState() => _TrajectoryScreenState();
}

class _TrajectoryScreenState extends State<TrajectoryScreen> {
  final LocationApi _api = LocationApi();
  DateTime _selected = DateTime.now();
  Map<String, dynamic>? _summary;
  bool _loading = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dateStr = _dateStr(_selected);
      final res = await _api.getTrajectoryDaySummary(dateStr);
      if (!mounted) return;
      setState(() {
        _summary = res;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _summary = null;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加载失败')));
    }
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtHm(String? iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final users = (_summary?['users'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('历史轨迹')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: CalendarDatePicker(
              key: ValueKey(_dateStr(_selected)),
              initialDate: _selected,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
              onDateChanged: (d) {
                setState(() => _selected = d);
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '选中日期：${_dateStr(_selected)}（UTC 日） · 每 2 小时一段',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? const Center(child: Text('该日暂无轨迹', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: users.length,
                        itemBuilder: (ctx, i) {
                          final u = users[i] as Map<String, dynamic>;
                          final phone = u['phone']?.toString() ?? '';
                          final nick = u['nickname']?.toString();
                          final segList = (u['segments'] as List?) ?? [];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ExpansionTile(
                              title: Text(nick != null && nick.isNotEmpty ? '$phone · $nick' : phone),
                              subtitle: Text('${segList.length} 段轨迹'),
                              children: segList.map<Widget>((seg) {
                                final s = seg as Map<String, dynamic>;
                                final start = s['start_time']?.toString();
                                final end = s['end_time']?.toString();
                                final cnt = s['point_count'];
                                final label =
                                    '${_fmtHm(start)}–${_fmtHm(end)} · $cnt 点';
                                return ListTile(
                                  title: Text(label),
                                  subtitle: const Text('开始–结束为本地时间显示'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => TrajectoryDetailScreen(
                                          userId: u['user_id'].toString(),
                                          startIso: start ?? '',
                                          endIso: end ?? '',
                                          title: '$phone $label',
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
