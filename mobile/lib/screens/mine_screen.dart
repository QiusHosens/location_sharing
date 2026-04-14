import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 底部「我的」：列表入口到轨迹、家庭、共享、设置
class MineScreen extends StatelessWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.timeline),
            title: const Text('轨迹'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/trajectory'),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('家庭'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/family'),
          ),
          ListTile(
            leading: const Icon(Icons.share_location),
            title: const Text('共享'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/sharing'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}
