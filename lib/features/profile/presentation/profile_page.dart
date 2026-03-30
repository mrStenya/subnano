import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../auth/domain/auth_service.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          // User info header
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 36,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.userMetadata?['full_name'] as String? ?? 'Guest',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (user?.email != null)
                        Text(
                          user!.email!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Menu items
          _MenuItem(
            icon: Icons.person_outline,
            title: 'Personal Information',
            onTap: () {
              // TODO: navigate to edit profile
            },
          ),
          _MenuItem(
            icon: Icons.document_scanner_outlined,
            title: 'Documents',
            subtitle: 'Diving license, ID',
            onTap: () {
              // TODO: navigate to documents
            },
          ),
          _MenuItem(
            icon: Icons.payment_outlined,
            title: 'Payment Methods',
            onTap: () {
              // TODO: navigate to payment methods
            },
          ),
          _MenuItem(
            icon: Icons.history,
            title: 'Booking History',
            onTap: () => context.go(AppRoutes.myBookings),
          ),
          const Divider(height: 1),
          _MenuItem(
            icon: Icons.info_outline,
            title: 'About SubNano',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'SubNano',
                applicationVersion: '1.0.0',
              );
            },
          ),
          _MenuItem(
            icon: Icons.logout,
            title: 'Sign Out',
            titleColor: Theme.of(context).colorScheme.error,
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go(AppRoutes.signIn);
            },
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: titleColor),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
