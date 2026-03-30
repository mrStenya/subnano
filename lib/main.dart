import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Validate required env vars at startup (fails fast in development)
  assert(Env.supabaseUrl.isNotEmpty, 'SUPABASE_URL is not set');
  assert(Env.supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY is not set');
  assert(
    Env.stripePublishableKey.isNotEmpty,
    'STRIPE_PUBLISHABLE_KEY is not set',
  );

  // Initialize Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // Initialize Stripe (publishable key only — safe in client)
  Stripe.publishableKey = Env.stripePublishableKey;
  await Stripe.instance.applySettings();

  runApp(
    // ProviderScope is the root for Riverpod
    const ProviderScope(child: SubNanoApp()),
  );
}

class SubNanoApp extends ConsumerWidget {
  const SubNanoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SubNano',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
