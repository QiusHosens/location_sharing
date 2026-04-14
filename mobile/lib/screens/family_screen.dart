import 'package:flutter/material.dart';
import '../api/user_api.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final UserApi _api = UserApi();
  List<dynamic> _groups = [];
  List<dynamic> _invitations = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final g = await _api.getGroups();
      final inv = await _api.getFamilyInvitations();
      if (mounted) {
        setState(() {
          _groups = g;
          _invitations = inv;
        });
      }
    } catch (_) {}
  }

  void _showCreateDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('创建家庭组'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: '名称')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          await _api.createGroup(ctrl.text);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          if (!mounted) return;
          _load();
        }, child: const Text('创建')),
      ],
    ));
  }

  void _showAddMemberDialog(String groupId) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('邀请成员'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '将向对方发送邀请通知，对方同意后方可加入家庭组。',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '对方手机号'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          try {
            await _api.addMember(groupId, ctrl.text);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (!mounted) return;
            _load();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('邀请已发送，对方同意后才会加入')),
            );
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('发送失败')),
            );
          }
        }, child: const Text('发送邀请')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('家庭组')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_invitations.isNotEmpty) ...[
              Text('待处理邀请', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ..._invitations.map((inv) {
                final name = inv['group_name']?.toString() ?? '';
                final who = inv['inviter_nickname']?.toString()
                    ?? inv['inviter_phone']?.toString()
                    ?? '';
                final id = inv['id']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$who 邀请你加入「$name」'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                try {
                                  await _api.respondFamilyInvitation(id, false);
                                  _load();
                                } catch (_) {}
                              },
                              child: const Text('拒绝'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                try {
                                  await _api.respondFamilyInvitation(id, true);
                                  _load();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已加入家庭组')),
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
              const SizedBox(height: 16),
            ],
            if (_groups.isEmpty && _invitations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Text('暂无家庭组', style: TextStyle(color: Colors.grey)),
                ),
              )
            else if (_groups.isEmpty)
              const SizedBox.shrink()
            else
              ..._groups.map((g) {
                final members = g['members'] as List? ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.group, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(g['name'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(width: 8),
                              Chip(label: Text('${members.length}人'), visualDensity: VisualDensity.compact),
                            ]),
                            Row(children: [
                              IconButton(
                                icon: const Icon(Icons.person_add, size: 20),
                                onPressed: () => _showAddMemberDialog(g['id']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () async {
                                  await _api.deleteGroup(g['id']);
                                  _load();
                                },
                              ),
                            ]),
                          ],
                        ),
                        const Divider(),
                        ...members.map<Widget>((m) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text((m['nickname'] ?? m['phone'] ?? '?')[0]),
                          ),
                          title: Text(m['nickname'] ?? m['phone'] ?? ''),
                          subtitle: Text(m['role'] == 'owner' ? '创建者' : '成员'),
                        )),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showCreateDialog, child: const Icon(Icons.add)),
    );
  }
}
