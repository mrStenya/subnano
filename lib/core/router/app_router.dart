import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/catalog/presentation/catalog_page.dart';
import '../../features/catalog/presentation/scooter_details_page.dart';
import '../../features/booking/presentation/booking_dates_page.dart';
import '../../features/checkout/presentation/checkout_page.dart';
import '../../features/orders/presentation/my_bookings_page.dart';
import '../../features/orders/presentation/booking_details_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/support/presentation/support_page.dart';
import '../../shared/widgets/main_shell.dart';
import '../config/env.dart';
import 'splash_page.dart';

// ---------------------------------------------------------------------------
// Route paths
// ---------------------------------------------------------------------------
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';

  // Shell branches
  static const catalog = '/catalog';
  static const scooterDetails = '/catalog/:id';
  static const bookingDates = '/catalog/:id/dates';
  static const checkout = '/catalog/:id/checkout';

  static const myBookings = '/bookings';
  static const bookingDetails = '/bookings/:bookingId';

  static const profile = '/profile';
  static const support = '/support';
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final routerProvider = Provider<GoRouter>((ref) {
  // TODO: watch auth state and redirect unauthenticated users to /sign-in
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: Env.isDevelopment,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, __) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (_, __) => const SignUpPage(),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.catalog,
            builder: (_, __) => const CatalogPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => ScooterDetailsPage(
                  scooterId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'dates',
                    builder: (_, state) => BookingDatesPage(
                      scooterId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'checkout',
                    builder: (_, state) => CheckoutPage(
                      scooterId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.myBookings,
            builder: (_, __) => const MyBookingsPage(),
            routes: [
              GoRoute(
                path: ':bookingId',
                builder: (_, state) => BookingDetailsPage(
                  bookingId: state.pathParameters['bookingId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfilePage(),
          ),
          GoRoute(
            path: AppRoutes.support,
            builder: (_, __) => const SupportPage(),
          ),
        ],
      ),
    ],
  );
});
