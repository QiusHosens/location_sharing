import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _minePaths = {
    '/me',
    '/trajectory',
    '/family',
    '/sharing',
    '/settings',
  };

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    if (location == '/notifications') {
      currentIndex = 1;
    } else if (_minePaths.contains(location)) {
      currentIndex = 2;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          final paths = ['/', '/notifications', '/me'];
          context.go(paths[i]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: '地图'),
          NavigationDestination(icon: Icon(Icons.notifications), label: '通知'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
