import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_router.dart';

/// Shown briefly on startup while checking auth state.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Small delay so splash is visible
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      context.go(AppRoutes.catalog);
    } else {
      context.go(AppRoutes.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water, size: 72, color: cs.onPrimary),
            const SizedBox(height: 16),
            Text(
              'SubNano',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Underwater Scooter Rentals',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimary.withOpacity(0.8),
                  ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(color: cs.onPrimary),
          ],
        ),
      ),
    );
  }
}
