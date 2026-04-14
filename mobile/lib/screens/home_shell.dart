import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  /// 与 [NavigationBar.destinations] 顺序一致：地图、家庭、足迹、设置
  static const _tabPaths = ['/', '/family', '/trajectory', '/settings'];

  static int indexForLocation(String location) {
    if (location == '/family' || location.startsWith('/family/')) return 1;
    if (location == '/trajectory' || location.startsWith('/trajectory/')) return 2;
    if (location == '/settings' || location.startsWith('/settings/')) return 3;
    if (location == '/sharing' || location == '/notifications') return 3;
    if (location == '/') return 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabPaths[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '地图'),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: '家庭',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: '足迹',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
