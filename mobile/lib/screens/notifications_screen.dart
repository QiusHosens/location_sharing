import 'package:flutter/material.dart';
import '../api/location_api.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final LocationApi _api = LocationApi();
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.getNotifications();
      setState(() { _notifications = res['items'] ?? []; _unreadCount = res['unread_count'] ?? 0; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知中心'), actions: [
        if (_unreadCount > 0) TextButton(onPressed: () async { await _api.markAllRead(); _load(); },
          child: const Text('全部已读')),
      ]),
      body: _notifications.isEmpty
        ? const Center(child: Text('暂无通知', style: TextStyle(color: Colors.grey)))
        : ListView.separated(
            itemCount: _notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final n = _notifications[i];
              return ListTile(
                tileColor: n['is_read'] == true ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                title: Text(n['title'] ?? n['type'] ?? '', style: TextStyle(fontWeight: n['is_read'] == true ? FontWeight.normal : FontWeight.bold)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (n['body'] != null) Text(n['body']),
                  Text(n['created_at'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                ]),
                trailing: n['is_read'] != true ? IconButton(icon: const Icon(Icons.mark_email_read, size: 20),
                  onPressed: () async { await _api.markRead(n['id']); _load(); }) : null,
              );
            }),
    );
  }
}
