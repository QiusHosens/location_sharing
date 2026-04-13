import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/user_api.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final UserApi _api = UserApi();
  final _nicknameCtrl = TextEditingController();
  String? _phone;

  @override
  void initState() {
    super.initState();
    _phone = ref.read(authProvider).phone;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _api.getProfile();
      _nicknameCtrl.text = p['nickname'] ?? '';
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await _api.updateProfile(nickname: _nicknameCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(Icons.person, size: 40, color: Theme.of(context).colorScheme.onPrimary),
          ),
          const SizedBox(height: 8),
          Text(_phone ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(controller: _nicknameCtrl, decoration: const InputDecoration(labelText: '昵称', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('保存修改'))),
        ]))),
        const SizedBox(height: 16),
        Card(child: Column(children: [
          ListTile(title: const Text('关于'), subtitle: const Text('定位共享 v0.1.0')),
          const Divider(height: 1),
          ListTile(
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () { ref.read(authProvider.notifier).logout(); context.go('/login'); },
          ),
        ])),
      ]),
    );
  }
}
