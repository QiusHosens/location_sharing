import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api/client.dart';
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
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/trajectory', builder: (_, __) => const TrajectoryScreen()),
          GoRoute(path: '/family', builder: (_, __) => const FamilyScreen()),
          GoRoute(path: '/sharing', builder: (_, __) => const SharingScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class LocationSharingApp extends ConsumerStatefulWidget {
  const LocationSharingApp({super.key});

  @override
  ConsumerState<LocationSharingApp> createState() => _LocationSharingAppState();
}

class _LocationSharingAppState extends ConsumerState<LocationSharingApp> {
  @override
  void initState() {
    super.initState();
    ApiClient.setUnauthorizedHandler(() => ref.read(authProvider.notifier).logout());
  }

  @override
  void dispose() {
    ApiClient.setUnauthorizedHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isAuthenticated == true && next.isAuthenticated == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ref.read(routerProvider).go('/login');
        });
      }
    });
    return MaterialApp.router(
      title: '位置共享',
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
