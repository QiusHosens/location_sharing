import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/family_screen.dart';
import 'screens/sharing_screen.dart';
import 'screens/trajectory_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/home_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  return GoRouter(
    redirect: (context, state) {
      if (!auth.isAuthenticated && state.matchedLocation != '/login') return '/login';
      if (auth.isAuthenticated && state.matchedLocation == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const MapScreen()),
          GoRoute(path: '/family', builder: (_, __) => const FamilyScreen()),
          GoRoute(path: '/sharing', builder: (_, __) => const SharingScreen()),
          GoRoute(path: '/trajectory', builder: (_, __) => const TrajectoryScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class LocationSharingApp extends ConsumerWidget {
  const LocationSharingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '定位共享',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      routerConfig: router,
    );
  }
}
