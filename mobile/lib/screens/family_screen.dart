import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/location_api.dart';
import '../api/user_api.dart';
import '../providers/auth_provider.dart';

/// 顶栏「家庭」+ 通知；支持多个家庭组并列展示，每组有组名、人数、独立「邀请」与成员列表；底部「创建家庭组」。
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final UserApi _api = UserApi();
  final LocationApi _locationApi = LocationApi();

  List<dynamic> _groups = [];
  List<dynamic> _invitations = [];

  /// `/sharing` 列表，用于判断 owner→viewer 是否共享
  List<dynamic> _sharingList = [];

  /// 家人最新定位里的电量（来自 `getFamilyLocations`）
  final Map<String, int?> _batteryByUserId = {};

  static const _accentBlue = Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await _api.getGroups();
      final inv = await _api.getFamilyInvitations();
      List<dynamic> sharing = [];
      try {
        sharing = await _api.getSharing();
      } catch (_) {}
      final battery = <String, int?>{};
      for (final raw in g) {
        final gid = raw is Map ? raw['id']?.toString() : null;
        if (gid == null) continue;
        try {
          final locs = await _locationApi.getFamilyLocations(gid);
          for (final l in locs) {
            if (l is! Map) continue;
            final uid = l['user_id']?.toString();
            if (uid == null) continue;
            final b = l['battery_level'];
            battery[uid] = b is int ? b : (b is num ? b.toInt() : null);
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _groups = g;
        _invitations = inv;
        _sharingList = sharing;
        _batteryByUserId
          ..clear()
          ..addAll(battery);
      });
    } catch (_) {}
  }

  /// 当前用户向对方共享位置：accepted 且未暂停
  bool _sharingOnForViewer(String viewerId) {
    final me = ref.read(authProvider).userId;
    if (me == null) return false;
    for (final s in _sharingList) {
      if (s is! Map) continue;
      if (s['owner_id']?.toString() != me ||
          s['viewer_id']?.toString() != viewerId)
        continue;
      final status = s['status']?.toString() ?? '';
      final paused = s['is_paused'] == true;
      return status == 'accepted' && !paused;
    }
    return false;
  }

  Future<void> _setShareToMember(String viewerId, bool enabled) async {
    try {
      await _api.setSharingPeer(viewerId, enabled);
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('共享设置失败')));
    }
  }

  Future<void> _callPhone(String phone) async {
    final t = phone.trim();
    if (t.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拨打电话'),
        content: Text('确认拨打 $t ？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accentBlue),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('拨打'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final uri = Uri(scheme: 'tel', path: t);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前设备不支持拨号')));
  }

  void _showCreateDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建家庭组'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accentBlue),
            onPressed: () async {
              await _api.createGroup(ctrl.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              await _load();
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(String groupId) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邀请成员'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将向对方发送邀请，对方同意后加入家庭组。', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '对方手机号',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accentBlue),
            onPressed: () async {
              try {
                await _api.addMember(groupId, ctrl.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('邀请已发送')));
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('发送失败')));
              }
            },
            child: const Text('发送邀请'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final auth = ref.watch(authProvider);
    final src = auth.phone ?? auth.userId ?? '?';
    final letter = src.isNotEmpty ? src[0] : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              letter.toUpperCase(),
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '家庭',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF111827),
            ),
            tooltip: '通知',
            onPressed: () => context.go('/notifications'),
          ),
        ],
      ),
    );
  }

  /// 每个家庭组一块：组名、人数、邀请、群主菜单
  Widget _groupSectionHeader({
    required String groupName,
    required int memberCount,
    required String groupId,
    required bool isOwner,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$memberCount 位成员',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _accentBlue,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _showAddMemberDialog(groupId),
            icon: const Icon(
              Icons.person_add_outlined,
              size: 20,
              color: _accentBlue,
            ),
            label: const Text('邀请', style: TextStyle(color: _accentBlue)),
          ),
          if (isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Color(0xFF6B7280)),
              onSelected: (v) async {
                if (v == 'delete') {
                  await _api.deleteGroup(groupId);
                  if (!mounted) return;
                  await _load();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'delete', child: Text('删除家庭组')),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _sliversForGroup(Map<String, dynamic> group, int groupIndex) {
    final gid = group['id']?.toString() ?? '';
    final groupName = group['name']?.toString() ?? '家庭组';
    final members =
        (group['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final auth = ref.watch(authProvider);
    final myId = auth.userId;
    final others = myId == null
        ? members
        : members.where((m) => m['user_id']?.toString() != myId).toList();
    final creatorId = group['creator_id']?.toString();
    final isOwner = creatorId != null && creatorId == myId;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: groupIndex == 0 ? 4 : 20),
          child: _groupSectionHeader(
            groupName: groupName,
            memberCount: members.length,
            groupId: gid,
            isOwner: isOwner,
          ),
        ),
      ),
      if (members.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(
                '暂无成员，点击「邀请」添加',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
        ),
      if (members.isNotEmpty && others.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(
                '暂无其他成员，点击「邀请」添加家人后可在此共享位置',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
        ),
      if (others.isNotEmpty)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _memberCard(others[i], i),
            childCount: others.length,
          ),
        ),
    ];
  }

  static const _statusIcons = [
    Icons.home_rounded,
    Icons.school_rounded,
    Icons.park_rounded,
  ];

  Widget _memberCard(Map<String, dynamic> m, int index) {
    final id = m['user_id']?.toString() ?? '';
    final name = m['nickname']?.toString() ?? m['phone']?.toString() ?? '家人';
    final phone = m['phone']?.toString() ?? '';
    final roleRaw = m['role']?.toString() ?? '';
    final roleLabel = roleRaw == 'owner' ? '创建者' : '成员';
    final letter = name.isNotEmpty ? name[0] : '?';
    final shareOn = _sharingOnForViewer(id);
    final batt = _batteryByUserId[id];
    final battLabel = batt != null ? '$batt% 电量' : '— 电量';
    final statusIcon = _statusIcons[index % _statusIcons.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: shareOn ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ColoredBox(
                            color: shareOn
                                ? Colors.blue.shade50
                                : Colors.grey.shade300,
                            child: Center(
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: shareOn
                                      ? Colors.blue.shade800
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusIcon,
                            size: 14,
                            color: shareOn
                                ? const Color(0xFF2E7D32)
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: shareOn
                              ? const Color(0xFF111827)
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shareOn
                            ? '$roleLabel • $battLabel'
                            : '$roleLabel • 已暂停共享',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: shareOn
                      ? const Color(0xFFE8F5E9)
                      : Colors.grey.shade200,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: shareOn ? () => _callPhone(phone) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.phone,
                        color: shareOn ? const Color(0xFF2E7D32) : Colors.grey,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: shareOn,
                  activeTrackColor: _accentBlue.withOpacity(0.5),
                  activeColor: _accentBlue,
                  onChanged: (v) => _setShareToMember(id, v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                color: _accentBlue,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_invitations.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '待处理邀请',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ..._invitations.map((inv) {
                                final name =
                                    inv['group_name']?.toString() ?? '';
                                final who =
                                    inv['inviter_nickname']?.toString() ??
                                    inv['inviter_phone']?.toString() ??
                                    '';
                                final id = inv['id']?.toString() ?? '';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('$who 邀请你加入「$name」'),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                try {
                                                  await _api
                                                      .respondFamilyInvitation(
                                                        id,
                                                        false,
                                                      );
                                                  await _load();
                                                } catch (_) {}
                                              },
                                              child: const Text('拒绝'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: _accentBlue,
                                              ),
                                              onPressed: () async {
                                                try {
                                                  await _api
                                                      .respondFamilyInvitation(
                                                        id,
                                                        true,
                                                      );
                                                  await _load();
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('已加入家庭组'),
                                                    ),
                                                  );
                                                } catch (_) {}
                                              },
                                              child: const Text('同意'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    if (_groups.isEmpty && _invitations.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.groups_outlined,
                                  size: 72,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '暂无家庭组',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '创建家庭组，邀请家人加入',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    for (var gi = 0; gi < _groups.length; gi++)
                      ..._sliversForGroup(
                        _groups[gi] as Map<String, dynamic>,
                        gi,
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 88)),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text(
                    '创建家庭组',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _showCreateDialog,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
