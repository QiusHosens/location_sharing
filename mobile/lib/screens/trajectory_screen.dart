import 'package:flutter/material.dart';

import '../api/location_api.dart';
import 'trajectory_detail_screen.dart';

const _accentBlue = Color(0xFF1877F2);

/// 设计稿：历史轨迹、月份与横向日期、家人可展开轨迹段列表
class TrajectoryScreen extends StatefulWidget {
  const TrajectoryScreen({super.key});

  @override
  State<TrajectoryScreen> createState() => _TrajectoryScreenState();
}

class _TrajectoryScreenState extends State<TrajectoryScreen> {
  final LocationApi _api = LocationApi();
  final ScrollController _dayStripController = ScrollController();

  late DateTime _selectedDay;
  Map<String, dynamic>? _summary;
  bool _loading = false;

  static const _weekdayCn = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// 横向日期条：从 [first] 到 [last]（含）逐日，可长距离滑动
  static const int _stripPastDays = 400;

  DateTime get _lastStripDay {
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  DateTime get _firstStripDay => _lastStripDay.subtract(Duration(days: _stripPastDays));

  int get _stripDayCount => _lastStripDay.difference(_firstStripDay).inDays + 1;

  DateTime _dayAtStripIndex(int i) => _firstStripDay.add(Duration(days: i));

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _selectedDay = DateTime(n.year, n.month, n.day);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollStripToSelected(animate: false));
  }

  @override
  void dispose() {
    _dayStripController.dispose();
    super.dispose();
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

  String _maskPhone(String p) {
    final t = p.trim();
    if (t.length < 8) return t;
    return '${t.substring(0, 3)}****${t.substring(t.length - 4)}';
  }

  void _scrollStripToSelected({bool animate = true}) {
    if (!_dayStripController.hasClients) return;
    final idx = _selectedDay.difference(_firstStripDay).inDays.clamp(0, _stripDayCount - 1);
    const itemExtent = 52.0 + 8.0;
    final max = _dayStripController.position.maxScrollExtent;
    final vw = MediaQuery.of(context).size.width;
    final target = (idx * itemExtent) - (vw / 2) + (itemExtent / 2);
    final offset = target.clamp(0.0, max);
    if (animate) {
      _dayStripController.animateTo(offset, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      _dayStripController.jumpTo(offset);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTrajectoryDaySummary(_dateStr(_selectedDay));
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

  Future<void> _pickDateBottomSheet() async {
    var temp = _selectedDay;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(ctx).bottom),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          const Expanded(
                            child: Text(
                              '选择日期',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              setState(() {
                                _selectedDay = DateTime(temp.year, temp.month, temp.day);
                              });
                              _load();
                              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollStripToSelected());
                            },
                            child: const Text('确定', style: TextStyle(color: _accentBlue, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 360,
                      child: CalendarDatePicker(
                        initialDate: temp,
                        firstDate: _firstStripDay,
                        lastDate: _lastStripDay,
                        onDateChanged: (d) {
                          setModal(() => temp = DateTime(d.year, d.month, d.day));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _avatarColor(int index) {
    const colors = [
      Color(0xFF5B8DEF),
      Color(0xFF4CAF50),
      Color(0xFFFFB74D),
      Color(0xFFAB47BC),
      Color(0xFF26A69A),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final users = (_summary?['users'] as List?) ?? [];
    final dateLabel = '${_selectedDay.year}年${_selectedDay.month}月${_selectedDay.day}日';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                '历史轨迹',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDateBottomSheet,
                    child: const Text('选择日期', style: TextStyle(color: _accentBlue, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 76,
              child: ListView.separated(
                controller: _dayStripController,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _stripDayCount,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final day = _dayAtStripIndex(i);
                  final sel = day.year == _selectedDay.year &&
                      day.month == _selectedDay.month &&
                      day.day == _selectedDay.day;
                  final wd = _weekdayCn[day.weekday - 1];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDay = DateTime(day.year, day.month, day.day));
                      _load();
                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollStripToSelected());
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      decoration: BoxDecoration(
                        color: sel ? _accentBlue : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          if (!sel) BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                        border: Border.all(color: sel ? _accentBlue : Colors.grey.shade200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            wd,
                            style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                color: _accentBlue,
                onRefresh: _load,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _accentBlue))
                    : users.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.route_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text('该日暂无轨迹', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                            itemCount: users.length,
                            itemBuilder: (ctx, i) {
                              final u = users[i] as Map<String, dynamic>;
                              return _MemberTrajectoryCard(
                                user: u,
                                index: i,
                                avatarColor: _avatarColor(i),
                                maskPhone: _maskPhone,
                                fmtHm: _fmtHm,
                                onSegmentTap: (startIso, endIso, label) {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => TrajectoryDetailScreen(
                                        userId: u['user_id'].toString(),
                                        startIso: startIso,
                                        endIso: endIso,
                                        title: label,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTrajectoryCard extends StatefulWidget {
  const _MemberTrajectoryCard({
    required this.user,
    required this.index,
    required this.avatarColor,
    required this.maskPhone,
    required this.fmtHm,
    required this.onSegmentTap,
  });

  final Map<String, dynamic> user;
  final int index;
  final Color avatarColor;
  final String Function(String) maskPhone;
  final String Function(String?) fmtHm;
  final void Function(String startIso, String endIso, String title) onSegmentTap;

  @override
  State<_MemberTrajectoryCard> createState() => _MemberTrajectoryCardState();
}

class _MemberTrajectoryCardState extends State<_MemberTrajectoryCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.index == 0;
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.user['phone']?.toString() ?? '';
    final nick = widget.user['nickname']?.toString();
    final segList = (widget.user['segments'] as List?) ?? [];
    final masked = widget.maskPhone(phone);
    final titleLine = (nick != null && nick.isNotEmpty) ? '$nick ($masked)' : '家人 ($masked)';
    final avatarLetter = (nick != null && nick.isNotEmpty) ? nick[0] : (phone.isNotEmpty ? phone[0] : '?');

    final segCount = segList.length;
    final summaryLine = segCount == 0
        ? '无记录 • 状态：静止'
        : '$segCount 条轨迹 • 今日已行 —';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: widget.avatarColor.withOpacity(0.25),
                    child: Text(
                      avatarLetter,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: widget.avatarColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleLine,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summaryLine,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
          if (_expanded && segList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: segList.map<Widget>((seg) {
                  final s = seg as Map<String, dynamic>;
                  final start = s['start_time']?.toString() ?? '';
                  final end = s['end_time']?.toString() ?? '';
                  final cnt = s['point_count'];
                  final timeRange = '${widget.fmtHm(start)} - ${widget.fmtHm(end)}';
                  final desc = '轨迹记录 · $cnt 个定位点';
                  final title = '$masked $timeRange';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onSegmentTap(start, end, title),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.blue.shade50,
                                  child: Icon(Icons.map_outlined, color: Colors.blue.shade300, size: 28),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      timeRange,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.phone_iphone, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(masked, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.blue.shade400),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
