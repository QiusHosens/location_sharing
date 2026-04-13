import 'package:flutter/material.dart';
import '../api/user_api.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final UserApi _api = UserApi();
  List<dynamic> _groups = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final g = await _api.getGroups(); setState(() => _groups = g); } catch (_) {}
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
      title: const Text('添加成员'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: '手机号')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          try {
            await _api.addMember(groupId, ctrl.text);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (!mounted) return;
            _load();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('成员已添加')));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('添加失败')));
          }
        }, child: const Text('添加')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('家庭组')),
      body: _groups.isEmpty
        ? const Center(child: Text('暂无家庭组', style: TextStyle(color: Colors.grey)))
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _groups.length, itemBuilder: (ctx, i) {
            final g = _groups[i];
            final members = g['members'] as List? ?? [];
            return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const Icon(Icons.group, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(g['name'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Chip(label: Text('${members.length}人'), visualDensity: VisualDensity.compact),
                  ]),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.person_add, size: 20), onPressed: () => _showAddMemberDialog(g['id'])),
                    IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () async {
                      await _api.deleteGroup(g['id']); _load();
                    }),
                  ]),
                ]),
                const Divider(),
                ...members.map<Widget>((m) => ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 16, child: Text((m['nickname'] ?? m['phone'] ?? '?')[0])),
                  title: Text(m['nickname'] ?? m['phone'] ?? ''),
                  subtitle: Text(m['role'] == 'owner' ? '创建者' : '成员'),
                )),
              ],
            )));
          }),
      floatingActionButton: FloatingActionButton(onPressed: _showCreateDialog, child: const Icon(Icons.add)),
    );
  }
}
