import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    if (location == '/family') currentIndex = 1;
    else if (location == '/sharing') currentIndex = 2;
    else if (location == '/trajectory') currentIndex = 3;
    else if (location == '/notifications') currentIndex = 4;
    else if (location == '/settings') currentIndex = 5;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          final paths = ['/', '/family', '/sharing', '/trajectory', '/notifications', '/settings'];
          context.go(paths[i]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: '地图'),
          NavigationDestination(icon: Icon(Icons.group), label: '家庭'),
          NavigationDestination(icon: Icon(Icons.share_location), label: '共享'),
          NavigationDestination(icon: Icon(Icons.timeline), label: '轨迹'),
          NavigationDestination(icon: Icon(Icons.notifications), label: '通知'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
