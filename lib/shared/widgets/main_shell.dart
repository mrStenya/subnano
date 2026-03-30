import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';

/// Bottom navigation shell wrapping the main sections.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _TabItem(label: 'Catalog', icon: Icons.water_outlined, route: AppRoutes.catalog),
    _TabItem(label: 'Bookings', icon: Icons.calendar_month_outlined, route: AppRoutes.myBookings),
    _TabItem(label: 'Profile', icon: Icons.person_outline, route: AppRoutes.profile),
    _TabItem(label: 'Support', icon: Icons.headset_mic_outlined, route: AppRoutes.support),
  ];

  int _activeIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.myBookings)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 2;
    if (location.startsWith(AppRoutes.support)) return 3;
    return 0; // catalog is default
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _activeIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].route),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
