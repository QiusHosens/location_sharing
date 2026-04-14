import 'package:flutter/material.dart';
import '../api/user_api.dart';

class SharingScreen extends StatefulWidget {
  const SharingScreen({super.key});
  @override State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  final UserApi _api = UserApi();
  List<dynamic> _sharingList = [];

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { _sharingList = await _api.getSharing(); setState(() {}); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('位置共享'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _showRequestDialog),
      ]),
      body: _sharingList.isEmpty
        ? const Center(child: Text('暂无共享记录', style: TextStyle(color: Colors.grey)))
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _sharingList.length, itemBuilder: (ctx, i) {
            final s = _sharingList[i];
            final statusColor = s['status'] == 'accepted' ? Colors.green : s['status'] == 'pending' ? Colors.orange : Colors.red;
            final statusText = s['status'] == 'accepted' ? '已接受' : s['status'] == 'pending' ? '待确认' : '已拒绝';
            return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
              leading: CircleAvatar(child: Text((s['peer_nickname'] ?? s['peer_phone'] ?? '?')[0])),
              title: Text(s['peer_nickname'] ?? s['peer_phone'] ?? ''),
              subtitle: Chip(label: Text(statusText), backgroundColor: statusColor.withOpacity(0.1),
                labelStyle: TextStyle(color: statusColor), visualDensity: VisualDensity.compact),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (s['status'] == 'pending')
                  ...[IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () async {
                    await _api.respondSharing(s['id'], true); _load(); }),
                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () async {
                    await _api.respondSharing(s['id'], false); _load(); })],
                if (s['status'] == 'accepted')
                  IconButton(icon: Icon(s['is_paused'] == true ? Icons.play_arrow : Icons.pause),
                    onPressed: () async { await _api.updateSharing(s['id'], isPaused: !(s['is_paused'] == true)); _load(); }),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () async {
                  await _api.deleteSharing(s['id']); _load(); }),
              ]),
            ));
          }),
    );
  }

  void _showRequestDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('请求位置共享'),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: '对方手机号',
          hintText: '对方账号已注册的手机号',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          try {
            await _api.requestSharing(ctrl.text);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (!mounted) return;
            _load();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请求已发送')));
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发送失败')));
          }
        }, child: const Text('发送')),
      ],
    ));
  }
}
