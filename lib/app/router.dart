import 'dart:async';

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/screens/admin/admin_dashboard_screen.dart';
import 'package:you_book/presentation/screens/auth/client_registration_screen.dart';
import 'package:you_book/presentation/screens/auth/onboarding_screen.dart';
import 'package:you_book/presentation/screens/auth/sign_in_screen.dart';
import 'package:you_book/presentation/screens/client/client_dashboard_screen.dart';
import 'package:you_book/presentation/screens/staff/staff_dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

GoRouter createRouter(Ref ref) {
  final sessionNotifier = ref.read(sessionControllerProvider.notifier);
  final refreshNotifier = _RouterRefreshNotifier(sessionNotifier.stream);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(
        path: '/',
        name: 'sign_in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'client_register',
        builder: (context, state) => const ClientRegistrationScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin_dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/staff',
        name: 'staff_dashboard',
        builder: (context, state) => const StaffDashboardScreen(),
      ),
      GoRoute(
        path: '/client',
        name: 'client_dashboard',
        builder: (context, state) => const ClientDashboardScreen(),
      ),
    ],
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final isAuthenticated = session.user != null;
      final loggingIn = state.matchedLocation == '/';
      final registering = state.matchedLocation == '/register';
      final onboarding = state.matchedLocation == '/onboarding';
      final requiresProfile = session.requiresProfile;

      if (!isAuthenticated) {
        if (loggingIn || registering) {
          return null;
        }
        return '/';
      }

      if (requiresProfile) {
        return onboarding ? null : '/onboarding';
      }

      final destination = _pathForRole(session.role);
      if (loggingIn) {
        return destination;
      }

      if (registering || onboarding) {
        return destination;
      }

      if (state.matchedLocation == '/admin' && session.role != UserRole.admin) {
        return destination;
      }
      if (state.matchedLocation == '/staff' && session.role != UserRole.staff) {
        return destination;
      }
      if (state.matchedLocation == '/client' &&
          session.role != UserRole.client) {
        return destination;
      }

      return null;
    },
  );
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

String _pathForRole(UserRole? role) {
  switch (role) {
    case UserRole.admin:
      return '/admin';
    case UserRole.staff:
      return '/staff';
    case UserRole.client:
      return '/client';
    case null:
      return '/';
  }
}
